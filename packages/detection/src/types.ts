/** Mirrors @subflow/shared — duplicated so the pure lib has zero workspace deps (offline eval). */
export type SubscriptionCadence = "weekly" | "monthly" | "yearly";

/** Minimal transaction view the engine needs — DB- and provider-agnostic. */
export interface TxInput {
  id: string;
  /** epoch milliseconds */
  time: number;
  description: string;
  mcc: number | null;
  /** minor units; negative = spend (engine only considers spends) */
  amount: number;
  currencyCode: number;
}

export interface ChargeRef {
  txId: string;
  time: number;
  /** absolute value, minor units */
  amount: number;
}

export interface DetectedSubscription {
  /** grouping key of the series (seed slug for seed matches, normName|mcc otherwise) */
  canonicalKey: string;
  displayName: string;
  /** set when the series matched the seed catalog */
  seedSlug?: string;
  /** container = Apple/Google aggregate billing, not decomposed in MVP */
  kind: "subscription" | "container";
  cadence: SubscriptionCadence;
  /** latest stable charge amount, minor units (absolute) */
  amountMinor: number;
  currencyCode: number;
  /** 0..1; >=0.8 auto-detected, 0.5..0.8 confirm-me, <0.5 not emitted */
  confidence: number;
  firstSeen: number;
  lastChargeAt: number;
  nextChargeAt: number;
  /** charges oldest→newest — the API layer derives charge/price_increase events */
  charges: ChargeRef[];
  /** diagnostics for eval/tuning */
  medianIntervalDays: number;
  intervalRegularity: number;
  amountCv: number;
  floatingAmount: boolean;
}

export interface EngineOptions {
  /** limit recompute to these canonical keys (incremental mode); omit = full run */
  scopeKeys?: string[];
  /** "now" for next_charge_at math — injectable for reproducible eval runs */
  now?: number;
}
