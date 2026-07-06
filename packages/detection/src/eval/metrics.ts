// Offline quality metrics (subF-12): engine output vs hand-labeled ground truth.
import type { DetectedSubscription } from "../types";

export interface LabeledSubscription {
  /** human name, e.g. "Netflix" */
  name: string;
  /** lowercase substring matched against detected displayName/canonicalKey */
  match: string;
  cadence?: "weekly" | "monthly" | "yearly";
  /** the person did not remember this subscription during labeling — the aha signal */
  forgotten?: boolean;
}

export interface PersonResult {
  person: string;
  highTier: TierResult;
  midTier: TierResult;
  /** labels the engine missed entirely (below 0.5 / not emitted) */
  missed: string[];
  /** forgotten labels that the engine DID find (any tier) */
  forgottenFound: string[];
  forgottenTotal: number;
}

export interface TierResult {
  truePositives: number;
  falsePositives: number;
  /** detected names that matched no label (the false positives themselves, for debugging) */
  fpNames: string[];
}

function matches(d: DetectedSubscription, label: LabeledSubscription): boolean {
  const m = label.match.toLowerCase();
  return d.displayName.toLowerCase().includes(m) || d.canonicalKey.toLowerCase().includes(m);
}

export function evaluatePerson(person: string, detected: DetectedSubscription[], labels: LabeledSubscription[]): PersonResult {
  const high = detected.filter((d) => d.confidence >= 0.8);
  const mid = detected.filter((d) => d.confidence >= 0.5 && d.confidence < 0.8);

  const tier = (ds: DetectedSubscription[]): TierResult => {
    let tp = 0;
    const fpNames: string[] = [];
    for (const d of ds) {
      if (labels.some((l) => matches(d, l))) tp++;
      else fpNames.push(d.displayName);
    }
    return { truePositives: tp, falsePositives: fpNames.length, fpNames };
  };

  const found = (l: LabeledSubscription) => detected.some((d) => matches(d, l));
  const missed = labels.filter((l) => !found(l)).map((l) => l.name);
  const forgotten = labels.filter((l) => l.forgotten);

  return {
    person,
    highTier: tier(high),
    midTier: tier(mid),
    missed,
    forgottenFound: forgotten.filter(found).map((l) => l.name),
    forgottenTotal: forgotten.length,
  };
}

export function precision(t: TierResult): number | null {
  const total = t.truePositives + t.falsePositives;
  return total === 0 ? null : t.truePositives / total;
}

export function aggregate(results: PersonResult[]) {
  const sum = (f: (r: PersonResult) => number) => results.reduce((a, r) => a + f(r), 0);
  const highTp = sum((r) => r.highTier.truePositives);
  const highFp = sum((r) => r.highTier.falsePositives);
  const midTp = sum((r) => r.midTier.truePositives);
  const midFp = sum((r) => r.midTier.falsePositives);
  const totalLabels = sum((r) => r.highTier.truePositives + r.midTier.truePositives + r.missed.length);
  const found = highTp + midTp;
  const personsWithForgottenFound = results.filter((r) => r.forgottenFound.length > 0).length;
  const personsWithForgottenLabels = results.filter((r) => r.forgottenTotal > 0).length;
  return {
    highPrecision: highTp + highFp === 0 ? null : highTp / (highTp + highFp),
    midPrecision: midTp + midFp === 0 ? null : midTp / (midTp + midFp),
    recall: totalLabels === 0 ? null : found / totalLabels,
    personsWithForgottenFound,
    personsWithForgottenLabels,
  };
}
