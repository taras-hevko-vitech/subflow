import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { and, eq } from "drizzle-orm";
import {
  BANK_PROVIDER,
  type BankProvider,
  ProviderError,
  TokenRevokedError,
} from "../bank/bank-provider";
import { initProviderLease } from "../bank/rate-limiter";
import { ENV, type Env } from "../config/env";
import { decryptToken, encryptToken } from "../crypto/token-cipher";
import { DB } from "../db/db.module";
import { accounts, bankConnections } from "../db/schema";
import type { Db } from "../db/types";

export interface ConnectResult {
  connectionId: string;
  accounts: Array<{
    id: string;
    type: string | null;
    currencyCode: number;
    maskedPan: string | null;
    isTracked: boolean;
  }>;
}

@Injectable()
export class ConnectionsService {
  constructor(
    @Inject(DB) private readonly maybeDb: Db | null,
    @Inject(ENV) private readonly env: Env,
    @Inject(BANK_PROVIDER) private readonly provider: BankProvider,
  ) {}

  private get db(): Db {
    if (!this.maybeDb) throw new ServiceUnavailableException("database not configured");
    return this.maybeDb;
  }

  private get encryptionKey(): string {
    const key = this.env.TOKEN_ENCRYPTION_KEY;
    if (!key) throw new ServiceUnavailableException("token encryption not configured");
    return key;
  }

  /**
   * Personal-token connect: validate immediately with client-info (also the moment the
   * user learns a paste went wrong), store the token encrypted, mirror the account list.
   * The validation call consumes the token's 60s window → the lease starts used.
   */
  async connectMonoPersonal(userId: string, token: string): Promise<ConnectResult> {
    let info: Awaited<ReturnType<BankProvider["getClientInfo"]>>;
    try {
      info = await this.provider.getClientInfo(token.trim());
    } catch (e) {
      if (e instanceof TokenRevokedError || (e instanceof ProviderError && e.status < 500)) {
        throw new BadRequestException(
          "Токен невалідний — перевір, чи скопіював його повністю з api.monobank.ua",
        );
      }
      throw new ServiceUnavailableException("monobank недоступний, спробуй за хвилину");
    }

    const [conn] = await this.db
      .insert(bankConnections)
      .values({
        userId,
        provider: "mono_personal",
        encryptedToken: encryptToken(token.trim(), this.encryptionKey),
      })
      .returning();
    if (!conn) throw new ServiceUnavailableException("connection insert failed");
    await initProviderLease(this.db, conn.id);

    const result: ConnectResult = { connectionId: conn.id, accounts: [] };
    for (const acc of info.accounts) {
      // FOP accounts default to untracked — business traffic is noise for detection.
      const isTracked = acc.type !== "fop";
      const [row] = await this.db
        .insert(accounts)
        .values({
          id: acc.id,
          connectionId: conn.id,
          type: acc.type,
          currencyCode: acc.currencyCode,
          maskedPan: acc.maskedPan,
          isTracked,
        })
        // reconnect case: the account already exists from a previous connection — rebind it
        .onConflictDoUpdate({
          target: accounts.id,
          set: { connectionId: conn.id, type: acc.type, maskedPan: acc.maskedPan },
        })
        .returning();
      if (row) {
        result.accounts.push({
          id: row.id,
          type: row.type,
          currencyCode: row.currencyCode,
          maskedPan: row.maskedPan,
          isTracked: row.isTracked,
        });
      }
    }
    return result;
  }

  async setAccountTracked(userId: string, accountId: string, isTracked: boolean) {
    // ownership check: the account must belong to one of the user's connections
    const [owned] = await this.db
      .select({ id: accounts.id })
      .from(accounts)
      .innerJoin(bankConnections, eq(accounts.connectionId, bankConnections.id))
      .where(and(eq(accounts.id, accountId), eq(bankConnections.userId, userId)))
      .limit(1);
    if (!owned) throw new NotFoundException();

    const [updated] = await this.db
      .update(accounts)
      .set({ isTracked })
      .where(eq(accounts.id, accountId))
      .returning();
    return { id: updated?.id, isTracked: updated?.isTracked };
  }

  /** 403 from mono on an existing connection → revoked; a push nudge follows in subF-16. */
  async markRevoked(connectionId: string): Promise<void> {
    await this.db
      .update(bankConnections)
      .set({ status: "revoked" })
      .where(eq(bankConnections.id, connectionId));
  }

  /**
   * Wrapper for every provider call made on behalf of a stored connection (backfill,
   * webhooks, watchdog). Decrypts the token and flips the connection to 'revoked' on 403
   * so jobs never spin on a dead token.
   */
  async withConnectionToken<T>(
    connectionId: string,
    fn: (token: string, provider: BankProvider) => Promise<T>,
  ): Promise<T> {
    const [conn] = await this.db
      .select()
      .from(bankConnections)
      .where(eq(bankConnections.id, connectionId))
      .limit(1);
    if (!conn) throw new NotFoundException("connection not found");
    try {
      return await fn(decryptToken(conn.encryptedToken, this.encryptionKey), this.provider);
    } catch (e) {
      if (e instanceof TokenRevokedError) {
        await this.markRevoked(connectionId);
      }
      throw e;
    }
  }
}
