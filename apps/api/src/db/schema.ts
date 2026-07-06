// Core domain schema (subF-7). Field semantics stay mappable to Berlin Group so a second
// provider / open-banking adapter reuses the same transactions table (see README mapping note).
//
// Postgres enum values must stay in sync with the string unions in @subflow/shared.
import { sql } from "drizzle-orm";
import {
  bigint,
  boolean,
  index,
  integer,
  jsonb,
  numeric,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core";

// --- enums (mirror @subflow/shared) ---
export const bankProviderEnum = pgEnum("bank_provider", ["mono_personal", "mono_provider"]);
export const connectionStatusEnum = pgEnum("connection_status", ["active", "revoked", "error"]);
export const cadenceEnum = pgEnum("subscription_cadence", ["weekly", "monthly", "yearly"]);
export const subscriptionStatusEnum = pgEnum("subscription_status", [
  "detected",
  "confirmed",
  "rejected",
  "container",
]);
export const subscriptionEventTypeEnum = pgEnum("subscription_event_type", [
  "charge",
  "price_increase",
  "missed",
]);
export const feedbackVerdictEnum = pgEnum("feedback_verdict", ["confirm", "reject"]);

// jsonb payloads
export interface BackfillProgress {
  /** total planned <=31d windows across the 12-month backfill */
  totalWindows: number;
  /** windows already ingested (resume point) */
  completedWindows: number;
  /** ISO timestamp of the oldest window boundary reached */
  oldestReached?: string;
}

// --- tables ---
export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  onboardingState: text("onboarding_state").notNull().default("new"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const deviceTokens = pgTable(
  "device_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    token: text("token").notNull(),
    platform: text("platform").notNull(), // 'ios' | 'android'
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex("device_tokens_user_token_uq").on(t.userId, t.token)],
);

export const bankConnections = pgTable("bank_connections", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  provider: bankProviderEnum("provider").notNull(),
  // AES-256-GCM ciphertext; key lives only in Secrets Manager, never here.
  encryptedToken: text("encrypted_token").notNull(),
  status: connectionStatusEnum("status").notNull().default("active"),
  backfillProgress: jsonb("backfill_progress").$type<BackfillProgress>(),
  webhookRegisteredAt: timestamp("webhook_registered_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const accounts = pgTable(
  "accounts",
  {
    id: text("id").primaryKey(), // mono account id
    connectionId: uuid("connection_id")
      .notNull()
      .references(() => bankConnections.id, { onDelete: "cascade" }),
    type: text("type"),
    currencyCode: integer("currency_code").notNull(), // ISO 4217 numeric
    maskedPan: text("masked_pan"),
    isTracked: boolean("is_tracked").notNull().default(true),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("accounts_connection_idx").on(t.connectionId)],
);

export const transactions = pgTable(
  "transactions",
  {
    id: text("id").primaryKey(), // mono tx id — natural dedup key
    accountId: text("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    time: timestamp("time", { withTimezone: true }).notNull(),
    description: text("description").notNull().default(""),
    mcc: integer("mcc"),
    amount: bigint("amount", { mode: "number" }).notNull(), // minor units, negative = spend
    currencyCode: integer("currency_code").notNull(),
    balance: bigint("balance", { mode: "number" }),
    raw: jsonb("raw").$type<Record<string, unknown>>().notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    index("transactions_account_time_idx").on(t.accountId, t.time),
    // trigram index powers merchant normalization / fuzzy matching (subF-11)
    index("transactions_description_trgm_idx").using("gin", sql`${t.description} gin_trgm_ops`),
  ],
);

export const merchants = pgTable("merchants", {
  id: uuid("id").primaryKey().defaultRandom(),
  canonicalKey: text("canonical_key").notNull().unique(), // norm_name + mcc
  displayName: text("display_name").notNull(),
  logoUrl: text("logo_url"),
  cancelUrl: text("cancel_url"),
  cancelInstructions: text("cancel_instructions"),
  isSeed: boolean("is_seed").notNull().default(false),
  patterns: jsonb("patterns").$type<string[]>(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const subscriptions = pgTable(
  "subscriptions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    merchantId: uuid("merchant_id")
      .notNull()
      .references(() => merchants.id),
    cadence: cadenceEnum("cadence").notNull(),
    amountMinor: bigint("amount_minor", { mode: "number" }).notNull(),
    currencyCode: integer("currency_code").notNull(),
    confidence: numeric("confidence", { precision: 4, scale: 3 }).notNull(),
    status: subscriptionStatusEnum("status").notNull().default("detected"),
    firstSeen: timestamp("first_seen", { withTimezone: true }).notNull(),
    lastChargeAt: timestamp("last_charge_at", { withTimezone: true }),
    nextChargeAt: timestamp("next_charge_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("subscriptions_user_merchant_uq").on(t.userId, t.merchantId),
    index("subscriptions_user_idx").on(t.userId),
  ],
);

export const subscriptionEvents = pgTable(
  "subscription_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    subscriptionId: uuid("subscription_id")
      .notNull()
      .references(() => subscriptions.id, { onDelete: "cascade" }),
    type: subscriptionEventTypeEnum("type").notNull(),
    txId: text("tx_id").references(() => transactions.id, { onDelete: "set null" }),
    oldAmount: bigint("old_amount", { mode: "number" }),
    newAmount: bigint("new_amount", { mode: "number" }),
    at: timestamp("at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("subscription_events_subscription_idx").on(t.subscriptionId)],
);

export const detectionFeedback = pgTable("detection_feedback", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  subscriptionId: uuid("subscription_id").references(() => subscriptions.id, {
    onDelete: "set null",
  }),
  txId: text("tx_id").references(() => transactions.id, { onDelete: "set null" }),
  verdict: feedbackVerdictEnum("verdict").notNull(),
  comment: text("comment"),
  at: timestamp("at", { withTimezone: true }).notNull().defaultNow(),
});

// --- bank integration (subF-8) ---
// DB-lease for the mono per-token limit (1 req/60s). One row per connection; acquiring is
// an atomic conditional UPDATE, so the limit holds across concurrent jobs and >1 API task.
export const providerRateLeases = pgTable("provider_rate_leases", {
  connectionId: uuid("connection_id")
    .primaryKey()
    .references(() => bankConnections.id, { onDelete: "cascade" }),
  nextAllowedAt: timestamp("next_allowed_at", { withTimezone: true }).notNull().defaultNow(),
});

// --- auth (subF-6) ---
// Keyed by email, not user id: requesting a link must not create a user (typo'd emails,
// enumeration). The user row is created on verify. Only the sha256 hash is stored.
export const magicLinkTokens = pgTable(
  "magic_link_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    email: text("email").notNull(),
    tokenHash: text("token_hash").notNull().unique(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    consumedAt: timestamp("consumed_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("magic_link_tokens_email_idx").on(t.email)],
);

// Rotated on every use; a rotated hash presented again = reuse (theft signal) and revokes
// the user's whole set. Only the sha256 hash is stored.
export const refreshTokens = pgTable(
  "refresh_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull().unique(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    rotatedAt: timestamp("rotated_at", { withTimezone: true }),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("refresh_tokens_user_idx").on(t.userId)],
);

// --- inferred types for the app layer ---
export type User = typeof users.$inferSelect;
export type BankConnection = typeof bankConnections.$inferSelect;
export type Account = typeof accounts.$inferSelect;
export type Transaction = typeof transactions.$inferSelect;
export type NewTransaction = typeof transactions.$inferInsert;
export type Merchant = typeof merchants.$inferSelect;
export type Subscription = typeof subscriptions.$inferSelect;
