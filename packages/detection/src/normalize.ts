// Merchant-string normalization — first stage of detection (subF-11).
// Bank `description` is dirty: processor prefixes, location tails, casing. We strip it down
// to a stable `canonicalKey` = normalized name + mcc, which later fuzzy-matches the seed
// catalog (pg_trgm) and groups a user's charges into a per-merchant time series.
//
// This is an intentionally small first cut. It grows against real samples from the dataset
// (subF-3) with table-driven unit tests; precision is measured in subF-12.

export interface NormalizedMerchant {
  /** cleaned, lowercased merchant name */
  normName: string;
  /** merchant category code, if present */
  mcc: number | null;
  /** grouping key: `${normName}|${mcc}` */
  canonicalKey: string;
}

/** Processor prefixes to drop, e.g. "PAYPAL *NETFLIX", "GPC *SPOTIFY", "SQ *GYM". */
const PROCESSOR_PREFIXES: RegExp[] = [
  /^paypal\s*\*\s*/i,
  /^gpc\s*\*\s*/i,
  /^sq\s*\*\s*/i,
  /^tst\s*\*\s*/i,
  /^www\./i,
];

/** Known aggregate/billing tails collapsed to a canonical vendor token. */
const REWRITES: Array<[RegExp, string]> = [
  [/apple\.com\/bill/i, "apple"],
  [/google\s*\*/i, "google"],
];

export function normalizeMerchant(
  description: string | null | undefined,
  mcc: number | null = null,
): NormalizedMerchant {
  let s = (description ?? "").toLowerCase().trim();

  for (const [re, to] of REWRITES) s = s.replace(re, to);
  for (const re of PROCESSOR_PREFIXES) s = s.replace(re, "");

  // collapse whitespace, drop noise chars but keep letters (incl. Cyrillic), digits, . * -
  s = s
    .replace(/\s+/g, " ")
    .replace(/[^\p{L}\p{N} .*-]/gu, "")
    .trim();

  const normName = s;
  return { normName, mcc, canonicalKey: `${normName}|${mcc ?? ""}` };
}
