# Subflow

Subscription tracker for monobank (Ukraine). Connect your monobank account → the service
automatically detects recurring charges → shows "here are your subscriptions, ₴/month and
₴/year, here's what you forgot about" → sends a push before each upcoming charge.
**Zero manual entry** — detection from bank transactions is the product.

Read-only: we only read statements. Bank tokens are encrypted at rest (AES-256-GCM);
tokens and raw statements never appear in logs.

## Stack

- **Mobile:** Flutter (Riverpod · go_router · dio + types generated from OpenAPI) — `apps/mobile` (subF-13+)
- **Backend:** NestJS (strict TS) — `apps/api`
- **DB / queue:** PostgreSQL + pg-boss (no Redis), Drizzle ORM
- **Infra:** AWS (ECS Fargate + RDS + ALB) via CDK v2 — `infra/` (subF-5)
- **Email:** SES · **Push:** FCM/APNs · **Observability:** Sentry + PostHog
- **Toolchain:** bun (package manager) + turborepo · Node 22 runtime

## Monorepo

```
apps/api            NestJS (HTTP + pg-boss jobs in one process)
apps/mobile         Flutter (subF-13+)
packages/shared     shared types/DTOs/enums (provider, cadence, status)
packages/detection  detection engine as a pure library (subF-11, offline eval in subF-12)
infra               AWS CDK v2 (subF-5), standalone bun project
tickets-mvp         backlog (subF-0-INDEX.md is the entry point)
```

## Local development

Requires: **Node 22** (`nvm use`), **bun**, **Docker** (for local Postgres).

```bash
bun install
docker compose up -d db          # local Postgres (port via DB_PORT, default 5432)
cd apps/api && bun run db:migrate # apply migrations
cd apps/api && bun run dev        # API on :3000, /health
```

Skeleton check: `curl localhost:3000/health` → `{"status":"ok",...}`.

Scripts (from the repo root): `bun run typecheck` · `bun run test` · `bun run lint` · `bun run build`.

## Data model

Core schema lives in `apps/api/src/db/schema.ts` (Drizzle), migrations in `apps/api/drizzle/`.
The `transactions` table keeps its field semantics mappable to **Berlin Group** (future open
banking): `id`↔transactionId, `time`↔bookingDate/valueDate, `description`↔remittanceInformation,
`amount` (minor units) + `currency_code`↔transactionAmount, `balance`↔balanceAfterTransaction.
A second provider (provider API / open banking) reuses the same table through a thin adapter.

## Backlog

See `tickets-mvp/subF-0-INDEX.md` — execution order, dependencies, go/no-go gates.
