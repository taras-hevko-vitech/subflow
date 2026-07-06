// Merchant-string normalization — first stage of detection (subF-11).
// Bank `description` is dirty: processor prefixes, location tails, casing. We strip it down
// to a stable `canonicalKey` = normalized name + mcc, which groups a user's charges into a
// per-merchant time series and feeds seed-catalog matching.

export interface NormalizedMerchant {
  /** cleaned, lowercased merchant name */
  normName: string;
  /** merchant category code, if present */
  mcc: number | null;
  /** grouping key: `${normName}|${mcc}` */
  canonicalKey: string;
}

/** Processor prefixes to drop, e.g. "PAYPAL *NETFLIX", "GPC *SPOTIFY", "SQ *GYM". */
const PROCESSOR_PREFIXES: RegExp[] = [/^paypal\s*\*\s*/i, /^gpc\s*\*\s*/i, /^sq\s*\*\s*/i, /^tst\s*\*\s*/i, /^www\./i];

/** Known aggregate/billing tails collapsed to a canonical vendor token. */
const REWRITES: Array<[RegExp, string]> = [
  [/apple\.com\/bill/i, "apple"],
  [/^google\s*\*.*$/i, "google"],
];

/** Location/branch tails that fragment one merchant into many keys. */
const LOCATION_TAILS: RegExp[] = [
  // trailing city names (latin + cyrillic), e.g. "AROMA KAVA KYIV", "SILPO ODESA"
  /\s+(kyiv|kiev|lviv|odesa|odessa|kharkiv|dnipro|київ|львів|одеса|харків|дніпро)\s*$/i,
  // trailing branch/store numbers: "SILPO #123", "WOG 0042"
  /\s*#?\d{2,6}\s*$/,
];

/** MCC 4829 = money transfer; those are person-to-person, never subscriptions. */
const TRANSFER_MCC = new Set([4829]);
const TRANSFER_DESCRIPTION = /^(від:|на:|переказ)/i;

export function normalizeMerchant(description: string | null | undefined, mcc: number | null = null): NormalizedMerchant {
  let s = (description ?? "").toLowerCase().trim();

  for (const [re, to] of REWRITES) s = s.replace(re, to);
  for (const re of PROCESSOR_PREFIXES) s = s.replace(re, "");

  // collapse whitespace, drop noise chars but keep letters (incl. Cyrillic), digits, . * -
  s = s
    .replace(/\s+/g, " ")
    .replace(/[^\p{L}\p{N} .*-]/gu, "")
    .trim();

  for (const re of LOCATION_TAILS) s = s.replace(re, "");
  s = s.trim();

  const normName = s;
  return { normName, mcc, canonicalKey: `${normName}|${mcc ?? ""}` };
}

/** P2P transfers and incoming money can never be subscriptions. */
export function isSubscriptionCandidate(tx: { amount: number; mcc: number | null; description: string }): boolean {
  if (tx.amount >= 0) return false;
  if (tx.mcc != null && TRANSFER_MCC.has(tx.mcc)) return false;
  if (TRANSFER_DESCRIPTION.test(tx.description.trim())) return false;
  return true;
}
