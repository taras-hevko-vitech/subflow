// subF-12 offline quality gate. Runs the engine over a labeled dataset and prints a
// markdown report with per-tier precision/recall and the "forgotten subscriptions" metric.
//
//   bun run eval                  # bundled synthetic fixtures (format demo / smoke run)
//   bun run eval -- --dir <path>  # real labeled dataset (PRIVATE — never in git)
//
// Dataset layout: <dir>/<person>/statement.json + labels.json (see eval/fixtures/).
// GATE B: high-tier precision >= 0.9 AND >=1 forgotten subscription found for at least
// half of the persons that labeled any. Exits 1 when the gate fails.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { detectSubscriptions } from "../engine";
import type { TxInput } from "../types";
import { type LabeledSubscription, type PersonResult, aggregate, evaluatePerson, precision } from "./metrics";

const args = process.argv.slice(2);
const dirFlag = args.indexOf("--dir");
// run from packages/detection (bun run eval); tsc (commonjs) disallows import.meta
const datasetDir = dirFlag >= 0 ? (args[dirFlag + 1] as string) : join(process.cwd(), "src/eval/fixtures");

interface RawTx {
  id: string;
  /** ISO string or epoch ms */
  time: string | number;
  description: string;
  mcc: number | null;
  amount: number;
  currencyCode: number;
}

const persons = readdirSync(datasetDir).filter((p) => statSync(join(datasetDir, p)).isDirectory());
if (persons.length === 0) {
  console.error(`no persons found in ${datasetDir}`);
  process.exit(1);
}

const results: PersonResult[] = [];
for (const person of persons) {
  const txsRaw = JSON.parse(readFileSync(join(datasetDir, person, "statement.json"), "utf8")) as RawTx[];
  const labels = (JSON.parse(readFileSync(join(datasetDir, person, "labels.json"), "utf8")) as { subscriptions: LabeledSubscription[] })
    .subscriptions;
  const txs: TxInput[] = txsRaw.map((t) => ({ ...t, time: typeof t.time === "number" ? t.time : Date.parse(t.time) }));
  // fixed "now" = last tx + 1d so old datasets evaluate the same way forever
  const now = Math.max(...txs.map((t) => t.time)) + 24 * 3600 * 1000;
  const detected = detectSubscriptions(txs, { now });
  results.push(evaluatePerson(person, detected, labels));
}

const agg = aggregate(results);
const pct = (x: number | null) => (x == null ? "n/a" : `${(x * 100).toFixed(1)}%`);

const lines: string[] = [];
lines.push("# Detection quality report (subF-12)");
lines.push("");
lines.push(`Dataset: \`${datasetDir}\` — ${persons.length} person(s)`);
lines.push("");
lines.push("| person | high-tier P | mid-tier P | missed | forgotten found | high FPs |");
lines.push("|---|---|---|---|---|---|");
for (const r of results) {
  lines.push(
    `| ${r.person} | ${pct(precision(r.highTier))} | ${pct(precision(r.midTier))} | ${r.missed.join(", ") || "—"} | ${
      r.forgottenFound.join(", ") || "—"
    } (${r.forgottenFound.length}/${r.forgottenTotal}) | ${r.highTier.fpNames.join(", ") || "—"} |`,
  );
}
lines.push("");
lines.push(`**Aggregate:** high-tier precision ${pct(agg.highPrecision)} · mid-tier ${pct(agg.midPrecision)} · recall ${pct(agg.recall)}`);
lines.push(`**Forgotten:** found for ${agg.personsWithForgottenFound}/${agg.personsWithForgottenLabels} person(s) with forgotten labels`);
lines.push("");

const gatePrecision = (agg.highPrecision ?? 0) >= 0.9;
const gateForgotten = agg.personsWithForgottenLabels === 0 || agg.personsWithForgottenFound * 2 >= agg.personsWithForgottenLabels;
lines.push(`## GATE B: ${gatePrecision && gateForgotten ? "✅ PASS" : "❌ FAIL"}`);
lines.push(`- precision ≥90% on high tier: ${gatePrecision ? "✅" : "❌"} (${pct(agg.highPrecision)})`);
lines.push(`- forgotten found for ≥½ of labeled persons: ${gateForgotten ? "✅" : "❌"}`);

console.log(lines.join("\n"));
process.exit(gatePrecision && gateForgotten ? 0 : 1);
