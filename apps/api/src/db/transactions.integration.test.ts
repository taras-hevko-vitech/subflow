import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import * as schema from "./schema";
import { accounts, bankConnections, transactions, users } from "./schema";
import { upsertTransaction } from "./transactions.repo";

const url = process.env.DATABASE_URL;

// Runs only when a Postgres URL is present (local `docker compose`, CI service). Skipped
// otherwise so the unit suite stays DB-free.
describe.skipIf(!url)("upsertTransaction (integration)", () => {
  let pool: Pool;
  let db: ReturnType<typeof drizzle<typeof schema>>;
  const txId = `tx-${randomUUID()}`;
  let accountId: string;

  beforeAll(async () => {
    pool = new Pool({ connectionString: url });
    db = drizzle(pool, { schema });
    const [u] = await db
      .insert(users)
      .values({ email: `${randomUUID()}@t.test` })
      .returning();
    if (!u) throw new Error("seed user failed");
    const [c] = await db
      .insert(bankConnections)
      .values({ userId: u.id, provider: "mono_personal", encryptedToken: "x" })
      .returning();
    if (!c) throw new Error("seed connection failed");
    accountId = `acc-${randomUUID()}`;
    await db.insert(accounts).values({ id: accountId, connectionId: c.id, currencyCode: 980 });
  });

  afterAll(async () => {
    // cascades to connections/accounts/transactions
    await pool.query("delete from users where email like '%@t.test'");
    await pool.end();
  });

  it("inserts once and is idempotent on the tx id", async () => {
    const base = {
      id: txId,
      accountId,
      time: new Date(),
      description: "NETFLIX",
      mcc: 4899,
      amount: -30000,
      currencyCode: 980,
      balance: 12345,
      raw: { a: 1 },
    };
    await upsertTransaction(db, base);
    await upsertTransaction(db, { ...base, description: "NETFLIX.COM", balance: 999 });

    const rows = await db.select().from(transactions).where(eq(transactions.id, txId));
    expect(rows).toHaveLength(1);
    const [row] = rows;
    expect(row?.description).toBe("NETFLIX.COM"); // update applied
    expect(row?.balance).toBe(999);
  });
});
