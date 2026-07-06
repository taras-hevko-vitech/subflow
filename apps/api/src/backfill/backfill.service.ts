import { Inject, Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";
import { and, eq, sql } from "drizzle-orm";
import type PgBoss from "pg-boss";
import { RateLimitedError, TokenRevokedError } from "../bank/bank-provider";
import { acquireProviderLease } from "../bank/rate-limiter";
import { ENV, type Env } from "../config/env";
import { ConnectionsService } from "../connections/connections.service";
import { DB } from "../db/db.module";
import { accounts, bankConnections } from "../db/schema";
import { upsertTransaction } from "../db/transactions.repo";
import type { Db } from "../db/types";
import { PG_BOSS } from "../jobs/jobs.module";

export const QUEUE_BACKFILL_PLAN = "backfill.plan";
export const QUEUE_BACKFILL_WINDOW = "backfill.window";
/** Stub consumer for now; the detection engine (subF-11) takes this queue over. */
export const QUEUE_DETECTION_RECOMPUTE = "detection.recompute";

/** mono window hard cap is 31 days + 1h; 30 keeps a margin. */
const WINDOW_DAYS = 30;
const BACKFILL_DAYS = 365;
/** The two newest windows (~2 months) jump the queue — partial results power the aha screen. */
const PRIORITY_WINDOWS = 2;
const HIGH_PRIORITY = 10;

export interface PlanJobData {
  connectionId: string;
}

export interface WindowJobData {
  connectionId: string;
  accountId: string;
  /** ISO timestamps; `to` shrinks on 500-item continuations, `from` is fixed. */
  from: string;
  to: string;
  priority: number;
}

@Injectable()
export class BackfillService {
  private readonly logger = new Logger(BackfillService.name);

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

  /** Fired from the connect flow; safe no-op when jobs are disabled (no DATABASE_URL). */
  async enqueuePlan(connectionId: string): Promise<void> {
    if (!this.boss) {
      this.logger.warn("pg-boss disabled — backfill not scheduled");
      return;
    }
    await this.boss.send(QUEUE_BACKFILL_PLAN, { connectionId } satisfies PlanJobData, {
      retryLimit: 5,
      retryDelay: 30,
    });
  }

  /**
   * Splits the last 12 months into ≤31-day windows per tracked account, newest first.
   * State (total/completed) lives in bank_connections.backfill_progress; the windows
   * themselves live as pg-boss jobs — a crash loses nothing because jobs persist in
   * Postgres and the tx upsert is idempotent.
   */
  async runPlan(data: PlanJobData): Promise<void> {
    if (!this.boss) return;
    const [conn] = await this.db.select().from(bankConnections).where(eq(bankConnections.id, data.connectionId)).limit(1);
    if (!conn || conn.status !== "active") return;

    const tracked = await this.db
      .select()
      .from(accounts)
      .where(and(eq(accounts.connectionId, data.connectionId), eq(accounts.isTracked, true)));
    if (tracked.length === 0) {
      this.logger.warn(`connection ${data.connectionId}: no tracked accounts, nothing to backfill`);
      return;
    }

    const windows = buildWindows(new Date());
    await this.db
      .update(bankConnections)
      .set({ backfillProgress: { totalWindows: windows.length * tracked.length, completedWindows: 0 } })
      .where(eq(bankConnections.id, data.connectionId));

    for (const account of tracked) {
      for (const [idx, w] of windows.entries()) {
        const priority = idx < PRIORITY_WINDOWS ? HIGH_PRIORITY : 0;
        await this.boss.send(
          QUEUE_BACKFILL_WINDOW,
          {
            connectionId: data.connectionId,
            accountId: account.id,
            from: w.from.toISOString(),
            to: w.to.toISOString(),
            priority,
          } satisfies WindowJobData,
          { priority, retryLimit: 8, retryDelay: 60, expireInSeconds: 120 },
        );
      }
    }
    this.logger.log(`connection ${data.connectionId}: planned ${windows.length * tracked.length} backfill windows`);
  }

  /**
   * One mono API call per invocation, gated by the per-token lease. Lease losers and
   * 500-item continuations reschedule themselves; only an exhausted window (<500 items)
   * counts toward progress.
   */
  async runWindow(data: WindowJobData): Promise<void> {
    if (!this.boss) return;

    // Dead token → drop silently; remaining jobs do the same as they surface.
    const [conn] = await this.db.select().from(bankConnections).where(eq(bankConnections.id, data.connectionId)).limit(1);
    if (!conn || conn.status !== "active") return;

    const lease = await acquireProviderLease(this.db, data.connectionId, this.env.MONO_LEASE_SECONDS);
    if (!lease.granted) {
      await this.reschedule(data, Math.ceil(lease.retryAfterMs / 1000));
      return;
    }

    let items: Awaited<ReturnType<typeof this.fetchWindow>>;
    try {
      items = await this.fetchWindow(data);
    } catch (e) {
      if (e instanceof TokenRevokedError) return; // withConnectionToken already flipped status
      if (e instanceof RateLimitedError) {
        await this.reschedule(data, this.env.MONO_LEASE_SECONDS);
        return;
      }
      throw e; // network/5xx → pg-boss retry with backoff
    }

    for (const item of items) {
      await upsertTransaction(this.db, {
        id: item.id,
        accountId: data.accountId,
        time: new Date(item.time * 1000),
        description: item.description,
        mcc: item.mcc,
        amount: item.amount,
        currencyCode: item.currencyCode,
        balance: item.balance,
        raw: item.raw,
      });
    }

    // mono returns max 500, sorted from the END of the period. A full page means the
    // window is not exhausted: shift `to` just before the oldest item and continue.
    if (items.length >= 500) {
      const oldest = items[items.length - 1];
      if (oldest) {
        await this.boss.send(
          QUEUE_BACKFILL_WINDOW,
          { ...data, to: new Date(oldest.time * 1000 - 1000).toISOString() } satisfies WindowJobData,
          { priority: data.priority, retryLimit: 8, retryDelay: 60, expireInSeconds: 120 },
        );
        return;
      }
    }

    await this.completeWindow(data);
  }

  private fetchWindow(data: WindowJobData) {
    return this.connections.withConnectionToken(data.connectionId, (token, provider) =>
      provider.getStatement(token, data.accountId, new Date(data.from), new Date(data.to)),
    );
  }

  private async reschedule(data: WindowJobData, delaySeconds: number): Promise<void> {
    if (!this.boss) return;
    const jitter = Math.floor(Math.random() * 5);
    await this.boss.send(QUEUE_BACKFILL_WINDOW, data, {
      startAfter: Math.max(1, delaySeconds) + jitter,
      priority: data.priority,
      retryLimit: 8,
      retryDelay: 60,
      expireInSeconds: 120,
    });
  }

  private async completeWindow(data: WindowJobData): Promise<void> {
    // Atomic increment inside jsonb — concurrent windows for other accounts race safely.
    const updated = await this.db.execute(
      sql`update bank_connections
          set backfill_progress = jsonb_set(
            backfill_progress,
            '{completedWindows}',
            (((backfill_progress->>'completedWindows')::int) + 1)::text::jsonb
          )
          where id = ${data.connectionId} and backfill_progress is not null
          returning (backfill_progress->>'completedWindows')::int as done,
                    (backfill_progress->>'totalWindows')::int as total`,
    );
    const row = updated.rows[0] as { done?: number; total?: number } | undefined;

    // Partial results become visible as soon as a window lands (subF-11 consumes this).
    await this.boss?.send(QUEUE_DETECTION_RECOMPUTE, {
      connectionId: data.connectionId,
      accountId: data.accountId,
    });

    if (row?.done != null && row.total != null && row.done >= row.total) {
      // backfill.completed: the "analysis done" push hangs off this in subF-16.
      this.logger.log(`connection ${data.connectionId}: backfill completed (${row.done}/${row.total} windows)`);
    }
  }

  async getProgress(userId: string, connectionId: string) {
    const [conn] = await this.db
      .select()
      .from(bankConnections)
      .where(and(eq(bankConnections.id, connectionId), eq(bankConnections.userId, userId)))
      .limit(1);
    if (!conn) return null;
    const p = conn.backfillProgress;
    return {
      status: conn.status,
      totalWindows: p?.totalWindows ?? 0,
      completedWindows: p?.completedWindows ?? 0,
      done: p != null && p.totalWindows > 0 && p.completedWindows >= p.totalWindows,
    };
  }
}

export function buildWindows(now: Date): Array<{ from: Date; to: Date }> {
  const windows: Array<{ from: Date; to: Date }> = [];
  const horizon = new Date(now.getTime() - BACKFILL_DAYS * 24 * 3600 * 1000);
  let to = now;
  while (to > horizon) {
    const from = new Date(Math.max(to.getTime() - WINDOW_DAYS * 24 * 3600 * 1000, horizon.getTime()));
    windows.push({ from, to });
    to = new Date(from.getTime() - 1000);
  }
  return windows; // newest first by construction
}
