import { randomUUID } from "node:crypto";
import { JwtService } from "@nestjs/jwt";
import { eq, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { Env } from "../config/env";
import * as schema from "../db/schema";
import {
  accounts,
  bankConnections,
  detectionFeedback,
  deviceTokens,
  magicLinkTokens,
  merchants,
  refreshTokens,
  subscriptionEvents,
  subscriptions,
  transactions,
  users,
} from "../db/schema";
import type { MailMessage, Mailer } from "../mail/mailer";
import { UsersService } from "../me/users.service";
import { AuthService } from "./auth.service";

const url = process.env.DATABASE_URL;

class CaptureMailer implements Mailer {
  readonly sent: MailMessage[] = [];
  async send(msg: MailMessage): Promise<void> {
    this.sent.push(msg);
  }
}

function tokenFromMail(msg: MailMessage): string {
  const m = msg.text.match(/auth\?token=([A-Za-z0-9_-]+)/);
  if (!m?.[1]) throw new Error("no token in mail");
  return m[1];
}

describe.skipIf(!url)("auth flow (integration)", () => {
  let pool: Pool;
  let db: ReturnType<typeof drizzle<typeof schema>>;
  let auth: AuthService;
  let usersService: UsersService;
  const mailer = new CaptureMailer();
  const email = `${randomUUID()}@auth.test`;

  beforeAll(() => {
    pool = new Pool({ connectionString: url });
    db = drizzle(pool, { schema });
    const env = { APP_BASE_URL: "http://localhost:3000" } as Env;
    const jwt = new JwtService({ secret: "test-secret-test-secret" });
    auth = new AuthService(db, env, mailer, jwt);
    usersService = new UsersService(db);
  });

  afterAll(async () => {
    await pool.query("delete from magic_link_tokens where email like '%@auth.test'");
    await pool.query("delete from users where email like '%@auth.test'");
    await pool.query("delete from merchants where canonical_key like 'authtest%'");
    await pool.end();
  });

  it("request → mail link → verify → JWT pair; token is single-use", async () => {
    await auth.requestMagicLink(email.toUpperCase()); // normalization check
    expect(mailer.sent).toHaveLength(1);
    const token = tokenFromMail(mailer.sent[0] as MailMessage);

    const pair = await auth.verifyMagicLink(token);
    expect(pair.accessToken).toBeTruthy();
    expect(pair.refreshToken).toBeTruthy();

    // user created with normalized email
    const [u] = await db.select().from(users).where(eq(users.email, email));
    expect(u).toBeTruthy();

    // consumed token cannot be replayed
    await expect(auth.verifyMagicLink(token)).rejects.toThrow(/invalid or expired/);
  });

  it("refresh rotates; reusing a rotated token revokes the whole set", async () => {
    await auth.requestMagicLink(email);
    const pair = await auth.verifyMagicLink(tokenFromMail(mailer.sent.at(-1) as MailMessage));

    const next = await auth.refresh(pair.refreshToken);
    expect(next.refreshToken).not.toBe(pair.refreshToken);

    // reuse of the OLD token → theft signal → everything revoked
    await expect(auth.refresh(pair.refreshToken)).rejects.toThrow(/reused/);
    await expect(auth.refresh(next.refreshToken)).rejects.toThrow();
  });

  it("rate-limits magic-link requests per email", async () => {
    const burst = `${randomUUID()}@auth.test`;
    for (let i = 0; i < 5; i++) await auth.requestMagicLink(burst);
    await expect(auth.requestMagicLink(burst)).rejects.toThrow(/too many/);
  });

  it("DELETE /me hard-deletes every user row (zero rows left)", async () => {
    // login
    await auth.requestMagicLink(email);
    await auth.verifyMagicLink(tokenFromMail(mailer.sent.at(-1) as MailMessage));
    const [u] = await db.select().from(users).where(eq(users.email, email));
    if (!u) throw new Error("no user");

    // populate the full graph
    await usersService.registerDeviceToken(u.id, "fcm-token-123", "android");
    const [conn] = await db
      .insert(bankConnections)
      .values({ userId: u.id, provider: "mono_personal", encryptedToken: "x" })
      .returning();
    if (!conn) throw new Error("no conn");
    const accId = `acc-${randomUUID()}`;
    await db.insert(accounts).values({ id: accId, connectionId: conn.id, currencyCode: 980 });
    const txId = `tx-${randomUUID()}`;
    await db.insert(transactions).values({
      id: txId,
      accountId: accId,
      time: new Date(),
      amount: -10000,
      currencyCode: 980,
      raw: {},
    });
    const [merchant] = await db
      .insert(merchants)
      .values({ canonicalKey: `authtest-${randomUUID()}`, displayName: "Test" })
      .returning();
    if (!merchant) throw new Error("no merchant");
    const [sub] = await db
      .insert(subscriptions)
      .values({
        userId: u.id,
        merchantId: merchant.id,
        cadence: "monthly",
        amountMinor: 10000,
        currencyCode: 980,
        confidence: "0.900",
        firstSeen: new Date(),
      })
      .returning();
    if (!sub) throw new Error("no sub");
    await db.insert(subscriptionEvents).values({ subscriptionId: sub.id, type: "charge", txId });
    await db
      .insert(detectionFeedback)
      .values({ userId: u.id, subscriptionId: sub.id, verdict: "confirm" });

    await usersService.hardDelete(u.id);

    const counts = await Promise.all(
      (
        [
          [users, sql`email = ${email}`],
          [deviceTokens, sql`user_id = ${u.id}`],
          [bankConnections, sql`user_id = ${u.id}`],
          [accounts, sql`id = ${accId}`],
          [transactions, sql`id = ${txId}`],
          [subscriptions, sql`user_id = ${u.id}`],
          [subscriptionEvents, sql`subscription_id = ${sub.id}`],
          [detectionFeedback, sql`user_id = ${u.id}`],
          [refreshTokens, sql`user_id = ${u.id}`],
          [magicLinkTokens, sql`email = ${email}`],
        ] as const
      ).map(async ([table, where]) => {
        const [row] = await db.select({ n: sql<number>`count(*)::int` }).from(table).where(where);
        return row?.n ?? -1;
      }),
    );
    expect(counts).toEqual([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

    // the global merchant catalog survives user deletion
    const [m] = await db.select().from(merchants).where(eq(merchants.id, merchant.id));
    expect(m).toBeTruthy();
  });
});
