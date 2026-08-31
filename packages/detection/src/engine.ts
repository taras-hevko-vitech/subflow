// The detection engine (subF-11): transactions in → detected subscriptions out.
// Pure function of its inputs — no DB, no clock (unless opts.now omitted) — so the offline
// quality gate (subF-12) can replay labeled statements byte-for-byte.
import { CADENCE_BANDS, FLOATING_CV, analyzeCadence, coefficientOfVariation, median } from "./cadence";
import { isSubscriptionCandidate, normalizeMerchant } from "./normalize";
import { type SeedMatch, matchSeed } from "./seed-catalog";
import type { ChargeRef, DetectedSubscription, EngineOptions, TxInput } from "./types";

const DAY_MS = 24 * 3600 * 1000;

/** Confidence weights: repeats / interval regularity / amount stability / seed match. */
const W_REPEATS = 0.3;
const W_REGULARITY = 0.3;
const W_AMOUNT = 0.2;
const W_SEED = 0.2;
/** Emission threshold — below this the series is ignored entirely. */
const MIN_CONFIDENCE = 0.5;
/** Floating-amount (utility-style) series can never auto-detect without user confirmation. */
const FLOATING_CAP = 0.79;
/** Typical-price tolerance for 1–2 charge seed detection. */
const PRICE_TOLERANCE = 0.15;
/** Amount deviation from the series median that marks a one-off purchase (same as recentStableAmount). */
const AMOUNT_OUTLIER_DEV = 0.5;
/** An outlier trim must leave at least this many charges to be trusted. */
const MIN_CORE_CHARGES = 3;
/**
 * MCCs where weekly/monthly regularity is everyday life, not a subscription (groceries,
 * fast food, restaurants, fuel, taxi, pharmacies). Penalized unless the seed catalog vouches.
 */
const NOISE_MCCS = new Set([5411, 5814, 5812, 5541, 5542, 4121, 5912]);
const NOISE_MCC_PENALTY = 0.2;

interface Series {
  canonicalKey: string;
  normName: string;
  mcc: number | null;
  seedMatch: SeedMatch | null;
  charges: ChargeRef[];
  currencyCode: number;
}

/** The series key a transaction lands in — used by the API for incremental (txId-scoped) recompute. */
export function seriesKeyFor(description: string, mcc: number | null): string | null {
  const norm = normalizeMerchant(description, mcc);
  if (!norm.normName) return null;
  const seed = matchSeed(norm.normName, norm.mcc);
  return seed ? `seed:${seed.seed.slug}` : norm.canonicalKey;
}

export function detectSubscriptions(txs: TxInput[], opts: EngineOptions = {}): DetectedSubscription[] {
  const now = opts.now ?? Date.now();
  const scope = opts.scopeKeys ? new Set(opts.scopeKeys) : null;

  // 1) group candidate spends into per-merchant series
  const series = new Map<string, Series>();
  for (const tx of txs) {
    if (!isSubscriptionCandidate(tx)) continue;
    const norm = normalizeMerchant(tx.description, tx.mcc);
    if (!norm.normName) continue;
    const seed = matchSeed(norm.normName, norm.mcc);
    // seed matches collapse variants (netflix.com|4899, paypal netflix|5968…) into one key
    const key = seed ? `seed:${seed.seed.slug}` : norm.canonicalKey;
    if (scope && !scope.has(key)) continue;
    let s = series.get(key);
    if (!s) {
      s = { canonicalKey: key, normName: norm.normName, mcc: norm.mcc, seedMatch: seed, charges: [], currencyCode: tx.currencyCode };
      series.set(key, s);
    }
    s.charges.push({ txId: tx.id, time: tx.time, amount: Math.abs(tx.amount) });
  }

  // 2) analyze each series
  const out: DetectedSubscription[] = [];
  for (const s of series.values()) {
    s.charges.sort((a, b) => a.time - b.time);
    const detected = analyzeSeries(s, now);
    if (detected) out.push(detected);
  }
  return out.sort((a, b) => b.confidence - a.confidence);
}

function analyzeSeries(s: Series, now: number): DetectedSubscription | null {
  const seed = s.seedMatch?.seed ?? null;
  const isContainer = !!seed?.container;
  // One-off purchases at a subscription merchant (API-token top-ups, gift cards) skew the
  // schedule and the confidence scores; drop them before analysis. Containers keep every
  // charge — Apple/Google aggregate amounts legitimately vary.
  const charges = isContainer ? s.charges : trimAmountOutliers(s.charges);
  const times = charges.map((c) => c.time);
  const amounts = charges.map((c) => c.amount);
  const analysis = analyzeCadence(times, amounts);

  let cadence = analysis.cadence;
  let confidence = 0;

  if (analysis.intervals.length >= 1 && cadence) {
    // main path: 2+ charges with a recognizable interval
    const repeatsScore = Math.min(analysis.intervals.length / 4, 1);
    const amountScore = analysis.floatingAmount ? 0 : 1 - Math.min(analysis.amountCv / 0.25, 1);
    const seedScore = s.seedMatch ? s.seedMatch.score : 0;
    confidence = W_REPEATS * repeatsScore + W_REGULARITY * analysis.regularity + W_AMOUNT * amountScore + W_SEED * seedScore;
    if (analysis.floatingAmount) confidence = Math.min(confidence, FLOATING_CAP);
    // regular grocery/coffee/fuel runs look like subscriptions but aren't — damp non-seed series
    if (!s.seedMatch && s.mcc != null && NOISE_MCCS.has(s.mcc)) confidence -= NOISE_MCC_PENALTY;
  } else if (seed && !isContainer && charges.length >= 1 && matchesTypicalPrice(seed.typicalPricesUah, amounts.at(-1) ?? 0)) {
    // seed + typical price → confirm-me candidate from 1–2 charges (yearly included)
    cadence = "monthly";
    confidence = charges.length >= 2 ? 0.65 : 0.5;
  } else if (!cadence && analysis.intervals.length >= 1 && seed) {
    // known service but odd interval — weak candidate
    cadence = "monthly";
    confidence = 0.5;
  } else {
    return null;
  }

  // containers: Apple/Google aggregates are real recurring charges we can't decompose —
  // always surfaced (as 'container'), regardless of scoring subtleties
  if (isContainer && charges.length >= 2 && cadence) {
    confidence = Math.max(confidence, 0.8);
  }

  if (confidence < MIN_CONFIDENCE) return null;
  if (!cadence) return null;

  const lastCharge = charges.at(-1) as ChargeRef;
  const stableAmount = recentStableAmount(amounts);
  const intervalDays = analysis.medianIntervalDays || defaultIntervalDays(cadence);

  return {
    canonicalKey: s.canonicalKey,
    displayName: seed?.displayName ?? prettify(s.normName),
    seedSlug: seed?.slug,
    kind: isContainer ? "container" : "subscription",
    cadence,
    amountMinor: stableAmount,
    currencyCode: s.currencyCode,
    confidence: round3(Math.min(confidence, 1)),
    firstSeen: (charges[0] as ChargeRef).time,
    lastChargeAt: lastCharge.time,
    nextChargeAt: lastCharge.time + Math.round(intervalDays * DAY_MS),
    charges,
    medianIntervalDays: round3(intervalDays),
    intervalRegularity: round3(analysis.regularity),
    amountCv: round3(analysis.amountCv),
    floatingAmount: analysis.floatingAmount,
  };
}

/**
 * Splits one-off purchases (amount off by >AMOUNT_OUTLIER_DEV from the series median) out of
 * a recurring series. Trims only when a genuinely stable core remains: at least
 * MIN_CORE_CHARGES charges whose amounts are non-floating — a utility-style series that
 * legitimately swings past the threshold is returned untouched.
 */
function trimAmountOutliers(charges: ChargeRef[]): ChargeRef[] {
  if (charges.length < MIN_CORE_CHARGES + 1) return charges;
  const med = median(charges.map((c) => c.amount));
  if (med <= 0) return charges;
  const core = charges.filter((c) => Math.abs(c.amount - med) / med <= AMOUNT_OUTLIER_DEV);
  if (core.length < MIN_CORE_CHARGES || core.length === charges.length) return charges;
  if (coefficientOfVariation(core.map((c) => c.amount)) > FLOATING_CV) return charges;
  return core;
}

/** Latest charge amount unless it's an outlier vs the recent median (refund glitches etc.). */
function recentStableAmount(amounts: number[]): number {
  const last = amounts.at(-1) ?? 0;
  if (amounts.length < 3) return last;
  const recentMedian = median(amounts.slice(-4));
  return Math.abs(last - recentMedian) / recentMedian > 0.5 ? recentMedian : last;
}

function matchesTypicalPrice(typical: number[] | undefined, amount: number): boolean {
  if (!typical?.length || amount <= 0) return false;
  return typical.some((p) => Math.abs(amount - p) / p <= PRICE_TOLERANCE);
}

function defaultIntervalDays(cadence: keyof typeof CADENCE_BANDS): number {
  const [lo, hi] = CADENCE_BANDS[cadence];
  return (lo + hi) / 2;
}

function prettify(normName: string): string {
  return normName
    .split(" ")
    .map((w) => (w ? w[0]?.toUpperCase() + w.slice(1) : w))
    .join(" ");
}

function round3(x: number): number {
  return Math.round(x * 1000) / 1000;
}
