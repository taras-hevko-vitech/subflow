// Domain enums shared across api / detection / (later) generated mobile types.
// Kept as const-objects (not TS `enum`) so they erase cleanly and serialize as plain strings.

export const BankProvider = {
  MonoPersonal: "mono_personal",
  MonoProvider: "mono_provider",
} as const;
export type BankProvider = (typeof BankProvider)[keyof typeof BankProvider];

export const ConnectionStatus = {
  Active: "active",
  Revoked: "revoked",
  Error: "error",
} as const;
export type ConnectionStatus = (typeof ConnectionStatus)[keyof typeof ConnectionStatus];

export const SubscriptionCadence = {
  Weekly: "weekly",
  Monthly: "monthly",
  Yearly: "yearly",
} as const;
export type SubscriptionCadence = (typeof SubscriptionCadence)[keyof typeof SubscriptionCadence];

export const SubscriptionStatus = {
  Detected: "detected",
  Confirmed: "confirmed",
  Rejected: "rejected",
  Container: "container",
} as const;
export type SubscriptionStatus = (typeof SubscriptionStatus)[keyof typeof SubscriptionStatus];

export const SubscriptionEventType = {
  Charge: "charge",
  PriceIncrease: "price_increase",
  Missed: "missed",
} as const;
export type SubscriptionEventType =
  (typeof SubscriptionEventType)[keyof typeof SubscriptionEventType];
