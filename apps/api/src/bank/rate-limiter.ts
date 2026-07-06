import { sql } from "drizzle-orm";
import { providerRateLeases } from "../db/schema";
import type { Db } from "../db/types";

export const LEASE_INTERVAL_S = 60;

export type LeaseResult = { granted: true } | { granted: false; retryAfterMs: number };

/**
 * Central enforcement of mono's 1 req/60s per-token limit. The claim is a single
 * conditional UPDATE — Postgres row locking serializes concurrent claimants, so exactly
 * one wins per window regardless of how many jobs or API tasks race. Callers that lose
 * get `retryAfterMs` and must reschedule (never drop work).
 */
export async function acquireProviderLease(db: Db, connectionId: string): Promise<LeaseResult> {
  const claimed = await db.execute(
    sql`update provider_rate_leases
        set next_allowed_at = now() + make_interval(secs => ${LEASE_INTERVAL_S})
        where connection_id = ${connectionId} and next_allowed_at <= now()
        returning connection_id`,
  );
  if (claimed.rows.length > 0) return { granted: true };

  const pending = await db.execute(
    sql`select extract(epoch from (next_allowed_at - now())) * 1000 as wait_ms
        from provider_rate_leases where connection_id = ${connectionId}`,
  );
  const waitMs = Number((pending.rows[0] as { wait_ms?: string | number })?.wait_ms ?? 0);
  return { granted: false, retryAfterMs: Math.max(0, Math.ceil(waitMs)) };
}

/** Called on connect: the validation client-info call just consumed this token's window. */
export async function initProviderLease(db: Db, connectionId: string): Promise<void> {
  await db
    .insert(providerRateLeases)
    .values({
      connectionId,
      nextAllowedAt: sql`now() + make_interval(secs => ${LEASE_INTERVAL_S})`,
    })
    .onConflictDoNothing();
}
