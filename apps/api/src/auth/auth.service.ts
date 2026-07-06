import { createHash, randomBytes } from "node:crypto";
import { HttpException, HttpStatus, Inject, Injectable, ServiceUnavailableException, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { and, eq, gt, isNull, sql } from "drizzle-orm";
import { ENV, type Env } from "../config/env";
import { DB } from "../db/db.module";
import { magicLinkTokens, refreshTokens, users } from "../db/schema";
import type { Db } from "../db/types";
import { MAILER, type Mailer } from "../mail/mailer";

const MAGIC_LINK_TTL_MS = 15 * 60 * 1000;
const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const ACCESS_TTL = "15m";
/** Max magic-link requests per email per hour. */
const REQUEST_LIMIT = 5;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(DB) private readonly maybeDb: Db | null,
    @Inject(ENV) private readonly env: Env,
    @Inject(MAILER) private readonly mailer: Mailer,
    private readonly jwt: JwtService,
  ) {}

  private get db(): Db {
    if (!this.maybeDb) throw new ServiceUnavailableException("database not configured");
    return this.maybeDb;
  }

  /** Always resolves (no user enumeration). Sends a one-time link with a 15-min TTL. */
  async requestMagicLink(email: string): Promise<void> {
    const normalized = email.trim().toLowerCase();

    const [{ recent }] = (await this.db
      .select({ recent: sql<number>`count(*)::int` })
      .from(magicLinkTokens)
      .where(and(eq(magicLinkTokens.email, normalized), gt(magicLinkTokens.createdAt, sql`now() - interval '1 hour'`)))) as [
      { recent: number },
    ];
    if (recent >= REQUEST_LIMIT) {
      throw new HttpException("too many requests", HttpStatus.TOO_MANY_REQUESTS);
    }

    const token = randomBytes(32).toString("base64url");
    await this.db.insert(magicLinkTokens).values({
      email: normalized,
      tokenHash: hashToken(token),
      expiresAt: new Date(Date.now() + MAGIC_LINK_TTL_MS),
    });

    // The raw token exists only in this mail; the DB holds its hash.
    await this.mailer.send({
      to: normalized,
      subject: "Вхід у Subflow",
      text: [
        "Привіт!",
        "",
        "Щоб увійти в Subflow, відкрий посилання (діє 15 хвилин):",
        `${this.env.APP_BASE_URL}/auth?token=${token}`,
        "",
        "Якщо це не ти — просто проігноруй цей лист.",
      ].join("\n"),
    });
  }

  /** Consumes the one-time token, creates the user on first login, returns a JWT pair. */
  async verifyMagicLink(token: string): Promise<TokenPair> {
    const [row] = await this.db
      .select()
      .from(magicLinkTokens)
      .where(
        and(eq(magicLinkTokens.tokenHash, hashToken(token)), isNull(magicLinkTokens.consumedAt), gt(magicLinkTokens.expiresAt, sql`now()`)),
      )
      .limit(1);
    if (!row) throw new UnauthorizedException("invalid or expired link");

    await this.db.update(magicLinkTokens).set({ consumedAt: new Date() }).where(eq(magicLinkTokens.id, row.id));

    const [user] = await this.db
      .insert(users)
      .values({ email: row.email })
      .onConflictDoUpdate({ target: users.email, set: { email: row.email } })
      .returning();
    if (!user) throw new ServiceUnavailableException("user upsert failed");

    return this.issuePair(user.id);
  }

  /** Rotates the refresh token. Presenting an already-used one revokes the whole set. */
  async refresh(refreshToken: string): Promise<TokenPair> {
    const [row] = await this.db
      .select()
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, hashToken(refreshToken)))
      .limit(1);
    if (!row) throw new UnauthorizedException("invalid refresh token");

    if (row.rotatedAt || row.revokedAt) {
      // Reuse of a rotated token = likely theft: kill every session for this user.
      await this.db
        .update(refreshTokens)
        .set({ revokedAt: new Date() })
        .where(and(eq(refreshTokens.userId, row.userId), isNull(refreshTokens.revokedAt)));
      throw new UnauthorizedException("refresh token reused");
    }
    if (row.expiresAt < new Date()) throw new UnauthorizedException("refresh token expired");

    await this.db.update(refreshTokens).set({ rotatedAt: new Date() }).where(eq(refreshTokens.id, row.id));
    return this.issuePair(row.userId);
  }

  private async issuePair(userId: string): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync({ sub: userId }, { expiresIn: ACCESS_TTL });
    const refreshToken = randomBytes(32).toString("base64url");
    await this.db.insert(refreshTokens).values({
      userId,
      tokenHash: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
    });
    return { accessToken, refreshToken };
  }
}
