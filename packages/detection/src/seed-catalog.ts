// Seed catalog of known subscription services (subF-11). Enables detection from 1–2 charges
// (typical prices), supplies logos/cancellation guidance, and marks Apple/Google aggregates
// as containers. Grown iteratively against the labeled dataset (subF-3 → subF-12 gate).
import { trigramSimilarity } from "./similarity";

export interface SeedMerchant {
  slug: string;
  displayName: string;
  /** lowercase substrings matched against the normalized name */
  patterns: string[];
  /** typical MCCs seen for this merchant (hint, not a hard filter) */
  mccs?: number[];
  /** typical monthly price points, UAH minor units (hint for 1–2-charge detection) */
  typicalPricesUah?: number[];
  logoUrl?: string;
  cancelUrl?: string;
  cancelInstructions?: string;
  /** aggregate biller (Apple/Google) — emitted as status=container, not decomposed in MVP */
  container?: boolean;
}

export const SEED_CATALOG: SeedMerchant[] = [
  // --- aggregates (containers) ---
  {
    slug: "apple",
    displayName: "Apple",
    patterns: ["apple", "apple.com bill", "itunes"],
    mccs: [5735, 5818],
    container: true,
    cancelUrl: "https://support.apple.com/uk-ua/HT202039",
    cancelInstructions: "Налаштування iPhone → Apple ID → Підписки — там видно, що саме списується.",
  },
  {
    slug: "google",
    displayName: "Google",
    patterns: ["google"],
    mccs: [5735, 5818, 5817],
    container: true,
    cancelUrl: "https://play.google.com/store/account/subscriptions",
    cancelInstructions: "Google Play → профіль → Платежі й підписки — список реальних сервісів усередині.",
  },
  // --- global streaming / music ---
  {
    slug: "netflix",
    displayName: "Netflix",
    patterns: ["netflix"],
    mccs: [4899, 5968],
    typicalPricesUah: [19900, 30000, 39000],
    cancelUrl: "https://www.netflix.com/cancelplan",
    cancelInstructions: "netflix.com → Account → Cancel membership. Діє до кінця оплаченого періоду.",
  },
  {
    slug: "spotify",
    displayName: "Spotify",
    patterns: ["spotify"],
    mccs: [5815],
    typicalPricesUah: [12500, 16900, 19900],
    cancelUrl: "https://www.spotify.com/ua-uk/account/subscription/",
    cancelInstructions: "spotify.com → Account → Your plan → Change plan → Cancel Premium.",
  },
  {
    slug: "youtube-premium",
    displayName: "YouTube Premium",
    patterns: ["youtube", "youtubepremium"],
    mccs: [5968, 5815],
    typicalPricesUah: [9900, 14900, 17900],
    cancelUrl: "https://www.youtube.com/paid_memberships",
    cancelInstructions: "youtube.com/paid_memberships → Manage membership → Deactivate.",
  },
  {
    slug: "disney-plus",
    displayName: "Disney+",
    patterns: ["disney"],
    typicalPricesUah: [24000, 35000],
    cancelUrl: "https://www.disneyplus.com/account",
  },
  {
    slug: "hbo-max",
    displayName: "Max (HBO)",
    patterns: ["hbo", "max.com"],
    typicalPricesUah: [24000, 38000],
  },
  // --- AI / dev / productivity ---
  {
    slug: "openai",
    displayName: "ChatGPT (OpenAI)",
    patterns: ["openai", "chatgpt"],
    mccs: [5734, 7372],
    typicalPricesUah: [83000, 92000],
    cancelUrl: "https://chat.openai.com/#settings",
    cancelInstructions: "chatgpt.com → Settings → Subscription → Manage → Cancel plan.",
  },
  {
    slug: "anthropic",
    displayName: "Claude (Anthropic)",
    patterns: ["anthropic", "claude.ai"],
    typicalPricesUah: [83000, 92000],
  },
  { slug: "github", displayName: "GitHub", patterns: ["github"], mccs: [5734, 7372], typicalPricesUah: [17000, 42000] },
  { slug: "adobe", displayName: "Adobe", patterns: ["adobe"], typicalPricesUah: [42000, 92000] },
  { slug: "dropbox", displayName: "Dropbox", patterns: ["dropbox"], typicalPricesUah: [46000] },
  { slug: "notion", displayName: "Notion", patterns: ["notion"], typicalPricesUah: [33000, 42000] },
  { slug: "figma", displayName: "Figma", patterns: ["figma"], typicalPricesUah: [50000, 63000] },
  // --- gaming ---
  { slug: "playstation", displayName: "PlayStation", patterns: ["playstation", "sony interactive"], typicalPricesUah: [24900, 45900] },
  { slug: "xbox", displayName: "Xbox", patterns: ["xbox", "microsoft*xbox"], typicalPricesUah: [22500, 45000] },
  { slug: "steam", displayName: "Steam", patterns: ["steam"], mccs: [5816] },
  // --- comms / social ---
  { slug: "telegram", displayName: "Telegram Premium", patterns: ["telegram"], typicalPricesUah: [17500, 20000] },
  { slug: "discord", displayName: "Discord Nitro", patterns: ["discord"], typicalPricesUah: [12500, 41500] },
  { slug: "patreon", displayName: "Patreon", patterns: ["patreon"] },
  { slug: "duolingo", displayName: "Duolingo", patterns: ["duolingo"], typicalPricesUah: [29000, 45000] },
  // --- Ukrainian streaming / TV ---
  {
    slug: "megogo",
    displayName: "MEGOGO",
    patterns: ["megogo"],
    mccs: [4899, 5815],
    typicalPricesUah: [9900, 19900, 29900],
    cancelUrl: "https://megogo.net/ua/settings/subscriptions",
    cancelInstructions: "megogo.net → профіль → Мої підписки → Відключити.",
  },
  {
    slug: "sweet-tv",
    displayName: "SWEET.TV",
    patterns: ["sweet.tv", "sweet tv", "sweettv"],
    mccs: [4899],
    typicalPricesUah: [13900, 19900, 29900],
    cancelUrl: "https://sweet.tv/account",
  },
  {
    slug: "kyivstar-tv",
    displayName: "Київстар ТБ",
    patterns: ["kyivstar tv", "київстар тб", "kyivstar tb"],
    mccs: [4899],
    typicalPricesUah: [9900, 19900],
  },
  {
    slug: "setanta",
    displayName: "Setanta Sports",
    patterns: ["setanta"],
    mccs: [4899],
    typicalPricesUah: [29900],
  },
  // --- Ukrainian mobile operators (regular top-ups behave like subscriptions) ---
  {
    slug: "kyivstar",
    displayName: "Київстар",
    patterns: ["kyivstar", "київстар"],
    mccs: [4814],
    cancelInstructions: "Тариф керується в застосунку «Мій Київстар».",
  },
  {
    slug: "vodafone-ua",
    displayName: "Vodafone UA",
    patterns: ["vodafone"],
    mccs: [4814],
    cancelInstructions: "Тариф керується в застосунку My Vodafone.",
  },
  {
    slug: "lifecell",
    displayName: "lifecell",
    patterns: ["lifecell"],
    mccs: [4814],
    cancelInstructions: "Тариф керується в застосунку lifecell.",
  },
  // --- gyms ---
  {
    slug: "sportlife",
    displayName: "Sport Life",
    patterns: ["sport life", "sportlife"],
    mccs: [7997],
    cancelInstructions: "Скасування — через клубний договір; напиши в підтримку клубу.",
  },
];

const FUZZY_THRESHOLD = 0.45;

export interface SeedMatch {
  seed: SeedMerchant;
  /** 1 for exact pattern hit, trigram similarity for fuzzy */
  score: number;
}

/** Exact substring pattern first (processor junk already stripped), then trigram fuzzy. */
export function matchSeed(normName: string, mcc: number | null): SeedMatch | null {
  if (!normName) return null;
  for (const seed of SEED_CATALOG) {
    if (seed.patterns.some((p) => normName.includes(p))) return { seed, score: 1 };
  }
  let best: SeedMatch | null = null;
  for (const seed of SEED_CATALOG) {
    for (const p of seed.patterns) {
      const s = trigramSimilarity(normName, p);
      if (s >= FUZZY_THRESHOLD && (!best || s > best.score)) best = { seed, score: s };
    }
  }
  // an MCC agreement nudges borderline fuzzy matches; disagreement doesn't veto (MCCs lie)
  if (best?.seed.mccs && mcc != null && best.seed.mccs.includes(mcc)) {
    best = { ...best, score: Math.min(1, best.score + 0.15) };
  }
  return best;
}
