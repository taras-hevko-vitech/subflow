import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import type * as schema from "./schema";
import { type NewTransaction, transactions } from "./schema";

export type Db = NodePgDatabase<typeof schema>;

// Idempotent upsert keyed on the mono tx id (natural dedup PK). Re-delivered webhooks and
// overlapping backfill windows (subF-9/subF-10) must never create duplicates.
export async function upsertTransaction(db: Db, tx: NewTransaction): Promise<void> {
  await db
    .insert(transactions)
    .values(tx)
    .onConflictDoUpdate({
      target: transactions.id,
      set: {
        description: tx.description ?? "",
        mcc: tx.mcc,
        amount: tx.amount,
        balance: tx.balance,
        raw: tx.raw,
      },
    });
}
