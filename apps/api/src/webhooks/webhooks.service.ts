import { Inject, Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";
import { and, eq, inArray, isNotNull, isNull, lt, or } from "drizzle-orm";
import type PgBoss from "pg-boss";
import { QUEUE_DETECTION_RECOMPUTE } from "../backfill/backfill.service";
import { RateLimitedError, TokenRevokedError } from "../bank/bank-provider";
import { acquireProviderLease } from "../bank/rate-limiter";
import { ENV, type Env } from "../config/env";
import { ConnectionsService } from "../connections/connections.service";
import { DB } from "../db/db.module";
import { accounts, bankConnections, transactions } from "../db/schema";
import { upsertTransaction } from "../db/transactions.repo";
import type { Db } from "../db/types";
import { PG_BOSS } from "../jobs/jobs.module";

export const QUEUE_WEBHOOK_EVENT = "webhook.event";
export const QUEUE_WEBHOOK_REGISTER = "webhook.register";
export const QUEUE_WEBHOOK_CHECK = "webhook.check";
export const QUEUE_WEBHOOK_WATCHDOG = "webhook.watchdog";

/** Silence longer than this on an active, registered connection triggers a control check. */
const WATCHDOG_SILENCE_HOURS = 48;
/** The control statement looks this far back for transactions the webhook should have sent. */
const CONTROL_WINDOW_HOURS = 24;

export interface MonoStatementItemPayload {
  id: string;
  time: number;
  description?: string;
  mcc: number;
  amount: number;
  currencyCode: number;
  balance: number;
  [key: string]: unknown;
}

export interface WebhookEventJob {
  connectionId: string;
  accountId: string;
  item: MonoStatementItemPayload;
}

export interface RegisterJob {
  connectionId: string;
}

@Injectable()
export class WebhooksService {
  private readonly logger = new Logger(WebhooksService.name);

  constructor(
    @Inject(DB) private readonly maybeDb: Db | null,
    @Inject(PG_BOSS) private readonly boss: PgBoss | null,
    @Inject(ENV) private readonly env: Env,
    private readonly connections: ConnectionsService,
  ) {}

  private get db(): Db {
    if (!this.maybeDb) throw new ServiceUnavailableException("database not configured");
    return this.maybeDb;
  }

  webhookUrl(connectionId: string): string {
    return `${this.env.WEBHOOK_BASE_URL ?? this.env.APP_BASE_URL}/webhooks/mono/${connectionId}`;
  }

  /** HTTP-time check: the path connection must exist and own the event's account. */
  async accountBelongsToConnection(connectionId: string, accountId: string): Promise<boolean> {
    const [row] = await this.db
      .select({ id: accounts.id })
      .from(accounts)
      .where(and(eq(accounts.id, accountId), eq(accounts.connectionId, connectionId)))
      .limit(1);
    return !!row;
  }

  /** Async consumer: upsert + progress detection + silence bookkeeping. Never called inline. */
  async processEvent(job: WebhookEventJob): Promise<void> {
    await this.ingest(job.connectionId, job.accountId, {
      id: job.item.id,
      time: job.item.time,
      description: job.item.description ?? "",
      mcc: job.item.mcc,
      amount: job.item.amount,
      currencyCode: job.item.currencyCode,
      balance: job.item.balance,
      raw: job.item,
    });
  }

  /** Shared by the webhook consumer and the watchdog gap recovery. */
  private async ingest(
    connectionId: string,
    accountId: string,
    tx: {
      id: string;
      time: number;
      description: string;
      mcc: number;
      amount: number;
      currencyCode: number;
      balance: number;
      raw: Record<string, unknown>;
    },
  ): Promise<void> {
    await upsertTransaction(this.db, {
      id: tx.id,
      accountId,
      time: new Date(tx.time * 1000),
      description: tx.description,
      mcc: tx.mcc,
      amount: tx.amount,
      currencyCode: tx.currencyCode,
      balance: tx.balance,
      raw: tx.raw,
    });
    await this.db.update(bankConnections).set({ lastWebhookAt: new Date() }).where(eq(bankConnections.id, connectionId));
    // incremental detection (subF-11) + "charge tomorrow" check (subF-16) hang off this
    await this.boss?.send(QUEUE_DETECTION_RECOMPUTE, { connectionId, accountId });
  }

  /** Lease-gated: registering the webhook is a mono API call like any other. */
  async register(job: RegisterJob): Promise<void> {
    const [conn] = await this.db.select().from(bankConnections).where(eq(bankConnections.id, job.connectionId)).limit(1);
    if (!conn || conn.status !== "active") return;

    const lease = await acquireProviderLease(this.db, job.connectionId, this.env.MONO_LEASE_SECONDS);
    if (!lease.granted) {
      await this.boss?.send(QUEUE_WEBHOOK_REGISTER, job, {
        startAfter: Math.max(1, Math.ceil(lease.retryAfterMs / 1000)) + Math.floor(Math.random() * 5),
        retryLimit: 8,
        retryDelay: 60,
      });
      return;
    }

    try {
      await this.connections.withConnectionToken(job.connectionId, (token, provider) =>
        provider.setWebhook(token, this.webhookUrl(job.connectionId)),
      );
    } catch (e) {
      if (e instanceof TokenRevokedError) return;
      if (e instanceof RateLimitedError) {
        await this.boss?.send(QUEUE_WEBHOOK_REGISTER, job, { startAfter: this.env.MONO_LEASE_SECONDS });
        return;
      }
      throw e; // 5xx/network → pg-boss retry
    }
    await this.db.update(bankConnections).set({ webhookRegisteredAt: new Date() }).where(eq(bankConnections.id, job.connectionId));
    this.logger.log(`connection ${job.connectionId}: webhook registered`);
  }

  /**
   * Daily sweep. mono silently disables a webhook after 3 failed deliveries, so silence is
   * the only signal — every quiet-too-long (or never-registered) connection gets a check job.
   */
  async watchdogSweep(): Promise<void> {
    const silenceCutoff = new Date(Date.now() - WATCHDOG_SILENCE_HOURS * 3600 * 1000);
    const suspects = await this.db
      .select({ id: bankConnections.id, registeredAt: bankConnections.webhookRegisteredAt })
      .from(bankConnections)
      .where(
        and(
          eq(bankConnections.status, "active"),
          or(
            isNull(bankConnections.webhookRegisteredAt),
            and(
              isNotNull(bankConnections.webhookRegisteredAt),
              or(isNull(bankConnections.lastWebhookAt), lt(bankConnections.lastWebhookAt, silenceCutoff)),
              lt(bankConnections.webhookRegisteredAt, silenceCutoff),
            ),
          ),
        ),
      );
    for (const s of suspects) {
      if (!s.registeredAt) {
        await this.boss?.send(QUEUE_WEBHOOK_REGISTER, { connectionId: s.id } satisfies RegisterJob);
      } else {
        await this.boss?.send(QUEUE_WEBHOOK_CHECK, { connectionId: s.id } satisfies RegisterJob);
      }
    }
    this.logger.log(`watchdog sweep: ${suspects.length} suspect connection(s)`);
  }

  /**
   * Control statement for one quiet connection: fetch the last 24h for its tracked accounts;
   * any transaction that is missing from our DB proves the webhook is dead → ingest the gap
   * right away, re-register, and scream into the log (Sentry picks up error level).
   */
  async checkConnection(job: RegisterJob): Promise<void> {
    const lease = await acquireProviderLease(this.db, job.connectionId, this.env.MONO_LEASE_SECONDS);
    if (!lease.granted) {
      await this.boss?.send(QUEUE_WEBHOOK_CHECK, job, {
        startAfter: Math.max(1, Math.ceil(lease.retryAfterMs / 1000)) + Math.floor(Math.random() * 5),
        retryLimit: 8,
        retryDelay: 60,
      });
      return;
    }

    const tracked = await this.db
      .select()
      .from(accounts)
      .where(and(eq(accounts.connectionId, job.connectionId), eq(accounts.isTracked, true)))
      .limit(1); // one account is enough as a canary; keeps it to a single lease
    const account = tracked[0];
    if (!account) return;

    const to = new Date();
    const from = new Date(to.getTime() - CONTROL_WINDOW_HOURS * 3600 * 1000);
    let items: Awaited<ReturnType<import("../bank/bank-provider").BankProvider["getStatement"]>>;
    try {
      items = await this.connections.withConnectionToken(job.connectionId, (token, provider) =>
        provider.getStatement(token, account.id, from, to),
      );
    } catch (e) {
      if (e instanceof TokenRevokedError) return;
      throw e;
    }
    if (items.length === 0) return; // genuinely quiet account — nothing to prove

    const known = await this.db
      .select({ id: transactions.id })
      .from(transactions)
      .where(
        inArray(
          transactions.id,
          items.map((i) => i.id),
        ),
      );
    const knownIds = new Set(known.map((k) => k.id));
    const missing = items.filter((i) => !knownIds.has(i.id));
    if (missing.length === 0) return; // webhook alive, account was just quiet

    this.logger.error(
      `connection ${job.connectionId}: webhook DEAD — ${missing.length} missed tx(s) in the last ${CONTROL_WINDOW_HOURS}h; recovering`,
    );
    for (const item of missing) {
      await this.ingest(job.connectionId, account.id, item);
    }
    await this.boss?.send(QUEUE_WEBHOOK_REGISTER, { connectionId: job.connectionId } satisfies RegisterJob);
  }
}
