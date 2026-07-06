// Provider-agnostic bank access (subF-8). MonoPersonalProvider is the MVP implementation;
// the provider API (subF-20) and open-banking adapters plug in behind the same interface.

export interface BankAccount {
  id: string;
  type: string | null;
  currencyCode: number;
  maskedPan: string | null;
  iban: string | null;
}

export interface BankClientInfo {
  clientId: string;
  name: string;
  webHookUrl: string | null;
  accounts: BankAccount[];
}

/** Field semantics follow mono / stay Berlin-Group-mappable (see README). */
export interface BankStatementItem {
  id: string;
  /** unix seconds as delivered by mono */
  time: number;
  description: string;
  mcc: number;
  amount: number;
  currencyCode: number;
  balance: number;
  raw: Record<string, unknown>;
}

export interface BankProvider {
  getClientInfo(token: string): Promise<BankClientInfo>;
  getStatement(token: string, accountId: string, from: Date, to: Date): Promise<BankStatementItem[]>;
  setWebhook(token: string, url: string): Promise<void>;
}

export const BANK_PROVIDER = Symbol("BANK_PROVIDER");

/** 403 from the bank: the user revoked the token → connection must flip to 'revoked'. */
export class TokenRevokedError extends Error {
  constructor() {
    super("bank token revoked");
  }
}

/** 429: hit the per-token limit; the job layer waits and retries, never drops work. */
export class RateLimitedError extends Error {
  constructor() {
    super("bank rate limit hit");
  }
}

export class ProviderError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}
