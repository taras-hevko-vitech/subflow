// Cadence detection over one merchant series (subF-11): intervals → cluster → regularity,
// amount stability via coefficient of variation. Pure math, tuned via the subF-12 gate.
import type { SubscriptionCadence } from "./types";

const DAY_MS = 24 * 3600 * 1000;

/** Interval bands per cadence (days). Ticket baselines widened slightly for real billing jitter. */
export const CADENCE_BANDS: Record<SubscriptionCadence, [number, number]> = {
  weekly: [5, 9],
  monthly: [26, 34],
  yearly: [330, 400],
};

/** Above this CV the amount is "floating" (utility-style) — still detectable, lower confidence. */
export const FLOATING_CV = 0.25;

export interface CadenceAnalysis {
  cadence: SubscriptionCadence | null;
  medianIntervalDays: number;
  /** share of intervals inside the winning band, 0..1 */
  regularity: number;
  /** coefficient of variation of charge amounts, 0 = perfectly stable */
  amountCv: number;
  floatingAmount: boolean;
  intervals: number[];
}

export function median(xs: number[]): number {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? (s[mid] as number) : ((s[mid - 1] as number) + (s[mid] as number)) / 2;
}

export function coefficientOfVariation(xs: number[]): number {
  if (xs.length < 2) return 0;
  const mean = xs.reduce((a, b) => a + b, 0) / xs.length;
  if (mean === 0) return 0;
  const variance = xs.reduce((a, b) => a + (b - mean) ** 2, 0) / xs.length;
  return Math.sqrt(variance) / mean;
}

export function cadenceFromInterval(days: number): SubscriptionCadence | null {
  for (const [cadence, [lo, hi]] of Object.entries(CADENCE_BANDS) as Array<[SubscriptionCadence, [number, number]]>) {
    if (days >= lo && days <= hi) return cadence;
  }
  return null;
}

/** `times` epoch-ms ascending, `amounts` absolute minor units aligned with charges. */
export function analyzeCadence(times: number[], amounts: number[]): CadenceAnalysis {
  const intervals: number[] = [];
  for (let i = 1; i < times.length; i++) intervals.push(((times[i] as number) - (times[i - 1] as number)) / DAY_MS);

  const med = median(intervals);
  const cadence = cadenceFromInterval(med);
  let regularity = 0;
  if (cadence && intervals.length > 0) {
    const [lo, hi] = CADENCE_BANDS[cadence];
    regularity = intervals.filter((d) => d >= lo && d <= hi).length / intervals.length;
  }
  const amountCv = coefficientOfVariation(amounts);
  return {
    cadence,
    medianIntervalDays: med,
    regularity,
    amountCv,
    floatingAmount: amountCv > FLOATING_CV,
    intervals,
  };
}
