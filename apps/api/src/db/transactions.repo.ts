import { type NewTransaction, transactions } from "./schema";
import type { Db } from "./types";

export type { Db } from "./types";

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
