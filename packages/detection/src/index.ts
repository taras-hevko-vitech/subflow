// Subscription detection engine (subF-11). Pure library — no DB, no Nest — so the offline
// quality harness (subF-12) can exercise it against hand-labeled statements.
export * from "./cadence";
export * from "./engine";
export * from "./normalize";
export * from "./seed-catalog";
export * from "./similarity";
export * from "./types";
