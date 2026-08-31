import { Inject, Injectable, Logger, NotFoundException, ServiceUnavailableException } from "@nestjs/common";
import { type DetectedSubscription, SEED_CATALOG, detectSubscriptions, seriesKeyFor } from "@subflow/detection";
import { and, eq, inArray } from "drizzle-orm";
import { DB } from "../db/db.module";
import { accounts, bankConnections, detectionFeedback, merchants, subscriptionEvents, subscriptions, transactions } from "../db/schema";
import type { Db } from "../db/types";

export interface RecomputeJob {
  connectionId: string;
  accountId?: string;
  /** present on webhook events → incremental recompute of just that merchant series */
  txId?: string;
}

const ACTIVE_STATUSES = ["detected", "confirmed", "container"] as const;
/** monthly-equivalent factors for totals */
const MONTHLY_FACTOR = { weekly: 52 / 12, monthly: 1, yearly: 1 / 12 } as const;
/** yearly-equivalent factors (for the per-subscription "costs you X/year") */
const YEARLY_FACTOR = { weekly: 52, monthly: 12, yearly: 1 } as const;
/** price bumps below this are billing noise (FX rounding etc.), not an increase */
const PRICE_INCREASE_MIN_RATIO = 0.02;
/** first_seen older than this → "давня" badge (a forgotten-subscription candidate) */
const OLD_MONTHS = 6;
/** nominal cadence intervals for staleness math */
const CADENCE_DAYS = { weekly: 7, monthly: 30.44, yearly: 365.25 } as const;
/**
 * No charge for longer than this many nominal intervals → the subscription looks
 * cancelled/lapsed (subF-22): excluded from the ₴ totals, surfaced separately.
 */
const LAPSE_FACTOR = 1.5;
const DAY_MS = 24 * 3600 * 1000;

function isLapsed(lastChargeAt: Date | null, cadence: keyof typeof CADENCE_DAYS, now: number): boolean {
  if (!lastChargeAt) return false;
  return now - lastChargeAt.getTime() > LAPSE_FACTOR * CADENCE_DAYS[cadence] * DAY_MS;
}

@Injectable()
export class DetectionService {
  private readonly logger = new Logger(DetectionService.name);

  constructor(@Inject(DB) private readonly maybeDb: Db | null) {}

  private get db(): Db {
    if (!this.maybeDb) throw new ServiceUnavailableException("database not configured");
    return this.maybeDb;
  }

  /** Boot-time idempotent seeding of the merchant catalog (logos, cancel guidance, patterns). */
  async seedMerchants(): Promise<void> {
    for (const seed of SEED_CATALOG) {
      await this.db
        .insert(merchants)
        .values({
          canonicalKey: `seed:${seed.slug}`,
          displayName: seed.displayName,
          logoUrl: seed.logoUrl,
          cancelUrl: seed.cancelUrl,
          cancelInstructions: seed.cancelInstructions,
          isSeed: true,
          patterns: seed.patterns,
        })
        .onConflictDoUpdate({
          target: merchants.canonicalKey,
          set: {
            displayName: seed.displayName,
            logoUrl: seed.logoUrl,
            cancelUrl: seed.cancelUrl,
            cancelInstructions: seed.cancelInstructions,
            isSeed: true,
            patterns: seed.patterns,
          },
        });
    }
  }

  /**
   * Recompute for the connection's user. With txId: only that transaction's merchant series
   * (incremental, webhook path, AC ≤1s). Without: the full user (backfill windows, ≤10s).
   */
  async recompute(job: RecomputeJob): Promise<void> {
    const started = Date.now();
    const [conn] = await this.db.select().from(bankConnections).where(eq(bankConnections.id, job.connectionId)).limit(1);
    if (!conn) return;

    // all txs across the user's tracked accounts (subscriptions are per user, not per card)
    const txs = await this.db
      .select({
        id: transactions.id,
        time: transactions.time,
        description: transactions.description,
        mcc: transactions.mcc,
        amount: transactions.amount,
        currencyCode: transactions.currencyCode,
      })
      .from(transactions)
      .innerJoin(accounts, eq(transactions.accountId, accounts.id))
      .innerJoin(bankConnections, eq(accounts.connectionId, bankConnections.id))
      .where(and(eq(bankConnections.userId, conn.userId), eq(accounts.isTracked, true)));

    let scopeKeys: string[] | undefined;
    if (job.txId) {
      const trigger = txs.find((t) => t.id === job.txId);
      const key = trigger ? seriesKeyFor(trigger.description, trigger.mcc) : null;
      if (!key) return; // trigger tx is not a subscription candidate — nothing to do
      scopeKeys = [key];
    }

    const detected = detectSubscriptions(
      txs.map((t) => ({ ...t, time: t.time.getTime() })),
      { scopeKeys },
    );
    for (const d of detected) {
      await this.persist(conn.userId, d);
    }
    this.logger.log(
      `recompute user=${conn.userId} scope=${scopeKeys ? "incremental" : "full"} txs=${txs.length} detected=${detected.length} in ${Date.now() - started}ms`,
    );
  }

  private async persist(userId: string, d: DetectedSubscription): Promise<void> {
    // merchant row: seed rows exist from boot seeding; organic merchants are created here
    let [merchant] = await this.db.select().from(merchants).where(eq(merchants.canonicalKey, d.canonicalKey)).limit(1);
    if (!merchant) {
      [merchant] = await this.db
        .insert(merchants)
        .values({ canonicalKey: d.canonicalKey, displayName: d.displayName, isSeed: false })
        .onConflictDoUpdate({ target: merchants.canonicalKey, set: { displayName: d.displayName } })
        .returning();
    }
    if (!merchant) return;

    const [existing] = await this.db
      .select()
      .from(subscriptions)
      .where(and(eq(subscriptions.userId, userId), eq(subscriptions.merchantId, merchant.id)))
      .limit(1);

    const targetStatus = d.kind === "container" ? "container" : "detected";
    const lastChargeTx = d.charges.at(-1);

    if (!existing) {
      await this.db.insert(subscriptions).values({
        userId,
        merchantId: merchant.id,
        cadence: d.cadence,
        amountMinor: d.amountMinor,
        currencyCode: d.currencyCode,
        confidence: String(d.confidence),
        status: targetStatus,
        firstSeen: new Date(d.firstSeen),
        lastChargeAt: new Date(d.lastChargeAt),
        nextChargeAt: new Date(d.nextChargeAt),
      });
      return; // historical charges are not "new" events
    }

    // user verdicts are sticky: rejected stays suppressed, confirmed stays confirmed
    const status = existing.status === "rejected" || existing.status === "confirmed" ? existing.status : targetStatus;

    // events BEFORE updating the row (diff against stored state)
    const prevLast = existing.lastChargeAt?.getTime() ?? 0;
    if (lastChargeTx && d.lastChargeAt > prevLast && existing.status !== "rejected") {
      await this.db.insert(subscriptionEvents).values({
        subscriptionId: existing.id,
        type: "charge",
        txId: lastChargeTx.txId,
      });
      if (existing.amountMinor > 0 && d.amountMinor > existing.amountMinor * (1 + PRICE_INCREASE_MIN_RATIO)) {
        await this.db.insert(subscriptionEvents).values({
          subscriptionId: existing.id,
          type: "price_increase",
          txId: lastChargeTx.txId,
          oldAmount: existing.amountMinor,
          newAmount: d.amountMinor,
        });
      }
    }

    await this.db
      .update(subscriptions)
      .set({
        cadence: d.cadence,
        amountMinor: d.amountMinor,
        currencyCode: d.currencyCode,
        confidence: String(d.confidence),
        status,
        firstSeen: new Date(Math.min(existing.firstSeen.getTime(), d.firstSeen)),
        lastChargeAt: new Date(d.lastChargeAt),
        nextChargeAt: new Date(d.nextChargeAt),
      })
      .where(eq(subscriptions.id, existing.id));
  }

  async list(userId: string) {
    const rows = await this.db
      .select({ sub: subscriptions, merchant: merchants })
      .from(subscriptions)
      .innerJoin(merchants, eq(subscriptions.merchantId, merchants.id))
      .where(and(eq(subscriptions.userId, userId), inArray(subscriptions.status, [...ACTIVE_STATUSES])));

    // one query for "recently increased" badges instead of N per-row lookups
    const increasedIds = await this.recentlyIncreased(rows.map((r) => r.sub.id));
    const oldCutoff = new Date();
    oldCutoff.setMonth(oldCutoff.getMonth() - OLD_MONTHS);

    let totalMonthlyMinor = 0;
    const now = Date.now();
    const items = rows
      .map(({ sub, merchant }) => {
        const monthlyEq = Math.round(sub.amountMinor * MONTHLY_FACTOR[sub.cadence]);
        const lapsed = isLapsed(sub.lastChargeAt, sub.cadence, now);
        if (sub.currencyCode === 980 && !lapsed) totalMonthlyMinor += monthlyEq;
        return {
          id: sub.id,
          merchant: {
            displayName: merchant.displayName,
            logoUrl: merchant.logoUrl,
            cancelUrl: merchant.cancelUrl,
            cancelInstructions: merchant.cancelInstructions,
            isSeed: merchant.isSeed,
          },
          cadence: sub.cadence,
          amountMinor: sub.amountMinor,
          currencyCode: sub.currencyCode,
          monthlyEqMinor: monthlyEq,
          yearlyEqMinor: Math.round(sub.amountMinor * YEARLY_FACTOR[sub.cadence]),
          confidence: Number(sub.confidence),
          status: sub.status,
          lapsed,
          firstSeen: sub.firstSeen,
          lastChargeAt: sub.lastChargeAt,
          nextChargeAt: sub.nextChargeAt,
          badges: {
            increased: increasedIds.has(sub.id),
            old: sub.firstSeen < oldCutoff,
            container: sub.status === "container",
          },
        };
      })
      .sort((a, b) => b.monthlyEqMinor - a.monthlyEqMinor);

    return {
      totalMonthlyMinor,
      totalYearlyMinor: totalMonthlyMinor * 12,
      currencyCode: 980,
      subscriptions: items,
    };
  }

  private async recentlyIncreased(subIds: string[]): Promise<Set<string>> {
    if (subIds.length === 0) return new Set();
    const rows = await this.db
      .selectDistinct({ id: subscriptionEvents.subscriptionId })
      .from(subscriptionEvents)
      .where(and(inArray(subscriptionEvents.subscriptionId, subIds), eq(subscriptionEvents.type, "price_increase")));
    return new Set(rows.map((r) => r.id));
  }

  /** Detail for the subscription card: charge history + price-change events + cancel guidance. */
  async detail(userId: string, subscriptionId: string) {
    const [row] = await this.db
      .select({ sub: subscriptions, merchant: merchants })
      .from(subscriptions)
      .innerJoin(merchants, eq(subscriptions.merchantId, merchants.id))
      .where(and(eq(subscriptions.id, subscriptionId), eq(subscriptions.userId, userId)))
      .limit(1);
    if (!row) throw new NotFoundException();

    const events = await this.db
      .select()
      .from(subscriptionEvents)
      .where(eq(subscriptionEvents.subscriptionId, subscriptionId))
      .orderBy(subscriptionEvents.at);

    return {
      id: row.sub.id,
      merchant: {
        displayName: row.merchant.displayName,
        logoUrl: row.merchant.logoUrl,
        cancelUrl: row.merchant.cancelUrl,
        cancelInstructions: row.merchant.cancelInstructions,
        isSeed: row.merchant.isSeed,
      },
      cadence: row.sub.cadence,
      amountMinor: row.sub.amountMinor,
      currencyCode: row.sub.currencyCode,
      yearlyEqMinor: Math.round(row.sub.amountMinor * YEARLY_FACTOR[row.sub.cadence]),
      status: row.sub.status,
      lapsed: isLapsed(row.sub.lastChargeAt, row.sub.cadence, Date.now()),
      firstSeen: row.sub.firstSeen,
      lastChargeAt: row.sub.lastChargeAt,
      nextChargeAt: row.sub.nextChargeAt,
      events: events.map((e) => ({
        type: e.type,
        at: e.at,
        oldAmount: e.oldAmount,
        newAmount: e.newAmount,
      })),
    };
  }

  async setVerdict(userId: string, subscriptionId: string, verdict: "confirm" | "reject", comment?: string) {
    const [sub] = await this.db
      .select()
      .from(subscriptions)
      .where(and(eq(subscriptions.id, subscriptionId), eq(subscriptions.userId, userId)))
      .limit(1);
    if (!sub) throw new NotFoundException();

    await this.db
      .update(subscriptions)
      .set({ status: verdict === "confirm" ? "confirmed" : "rejected" })
      .where(eq(subscriptions.id, sub.id));
    await this.db.insert(detectionFeedback).values({ userId, subscriptionId: sub.id, verdict, comment });
    return { id: sub.id, status: verdict === "confirm" ? "confirmed" : "rejected" };
  }
}
