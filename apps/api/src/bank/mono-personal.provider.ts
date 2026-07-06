import {
  type BankAccount,
  type BankClientInfo,
  type BankProvider,
  type BankStatementItem,
  ProviderError,
  RateLimitedError,
  TokenRevokedError,
} from "./bank-provider";

const TIMEOUT_MS = 10_000;
const RETRIES = 2; // on 5xx / network only; 4xx are semantic and never retried

interface MonoAccount {
  id: string;
  type?: string;
  currencyCode: number;
  maskedPan?: string[];
  iban?: string;
}

interface MonoClientInfo {
  clientId: string;
  name: string;
  webHookUrl?: string;
  accounts: MonoAccount[];
}

interface MonoStatementItem {
  id: string;
  time: number;
  description?: string;
  mcc: number;
  amount: number;
  currencyCode: number;
  balance: number;
  [key: string]: unknown;
}

/**
 * monobank personal API: X-Token auth, no refresh cycle. The 1 req/60s per-token limit is
 * NOT enforced here — the central DB-lease limiter (rate-limiter.ts) owns that; this class
 * only maps transport and error semantics.
 */
export class MonoPersonalProvider implements BankProvider {
  constructor(private readonly baseUrl: string) {}

  async getClientInfo(token: string): Promise<BankClientInfo> {
    const data = await this.get<MonoClientInfo>("/personal/client-info", token);
    return {
      clientId: data.clientId,
      name: data.name,
      webHookUrl: data.webHookUrl ?? null,
      accounts: data.accounts.map(
        (a): BankAccount => ({
          id: a.id,
          type: a.type ?? null,
          currencyCode: a.currencyCode,
          maskedPan: a.maskedPan?.[0] ?? null,
          iban: a.iban ?? null,
        }),
      ),
    };
  }

  async getStatement(token: string, accountId: string, from: Date, to: Date): Promise<BankStatementItem[]> {
    const f = Math.floor(from.getTime() / 1000);
    const t = Math.floor(to.getTime() / 1000);
    const items = await this.get<MonoStatementItem[]>(`/personal/statement/${accountId}/${f}/${t}`, token);
    return items.map((i) => ({
      id: i.id,
      time: i.time,
      description: i.description ?? "",
      mcc: i.mcc,
      amount: i.amount,
      currencyCode: i.currencyCode,
      balance: i.balance,
      raw: i,
    }));
  }

  async setWebhook(token: string, url: string): Promise<void> {
    await this.request("POST", "/personal/webhook", token, { webHookUrl: url });
  }

  private async get<T>(path: string, token: string): Promise<T> {
    return (await this.request("GET", path, token)) as T;
  }

  private async request(method: "GET" | "POST", path: string, token: string, body?: unknown): Promise<unknown> {
    let lastError: unknown;
    for (let attempt = 0; attempt <= RETRIES; attempt++) {
      if (attempt > 0) await sleep(500 * 2 ** (attempt - 1));
      try {
        const res = await fetch(`${this.baseUrl}${path}`, {
          method,
          headers: {
            "X-Token": token,
            ...(body ? { "content-type": "application/json" } : {}),
          },
          body: body ? JSON.stringify(body) : undefined,
          signal: AbortSignal.timeout(TIMEOUT_MS),
        });

        if (res.status === 403 || res.status === 401) throw new TokenRevokedError();
        if (res.status === 429) throw new RateLimitedError();
        if (res.status >= 500) {
          lastError = new ProviderError(res.status, `mono ${res.status}`);
          continue; // retry with backoff
        }
        if (!res.ok) throw new ProviderError(res.status, `mono ${res.status}`);
        return res.status === 204 ? undefined : await res.json();
      } catch (e) {
        if (e instanceof TokenRevokedError || e instanceof RateLimitedError || e instanceof ProviderError) {
          throw e;
        }
        lastError = e; // network / timeout → retry
      }
    }
    throw lastError instanceof Error ? lastError : new ProviderError(0, "mono unreachable");
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
