# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Subflow — subscription tracker for monobank (Ukraine). Users connect their monobank account via a personal API token; the service detects recurring charges from bank transactions (zero manual entry), shows ₴/month + ₴/year totals, and pushes before upcoming charges. Read-only posture: we only read statements.

The backlog lives in `tickets-mvp/` (`subF-0-INDEX.md` is the entry point — execution order, dependencies, and two go/no-go gates). Work is done per ticket: branch `feat/subF-N-...` off `main`, conventional commits, squash-merge PRs.

## Hard rules

- **Communicate with the user in Ukrainian; code, comments, and commit messages in English.**
- **NO TESTS.** Product decision: test suites and vitest were removed; do not write or commit tests. Verify features via live runs instead (boot the API, curl the endpoints, mock external services with throwaway scripts in the scratchpad, check the DB with psql). The offline detection-quality eval (subF-12 gate) is a product script, not a test — it stays.
- **Never put `claude.ai/code/session_...` links in commits, PR bodies, or anything pushed to GitHub.** Plain `Co-Authored-By` trailer is fine.
- Bank tokens and raw statements must never appear in logs (pino redaction is configured — keep it intact) and tokens are stored AES-256-GCM encrypted only.
- Run `bun run lint` before pushing — CI runs it and hand-written files usually need `bunx biome check --write .` first.

## Toolchain & commands

Node 22 via nvm + **bun** as package manager (not npm/pnpm). Non-interactive shells fall back to a system Node 16 — prefix commands with:

```bash
export PATH="$HOME/.nvm/versions/node/v22.16.0/bin:$PATH"
```

```bash
bun install                       # root workspaces: apps/*, packages/*
bun run lint                      # Biome (check only); fix: bunx biome check --write .
bun run typecheck                 # turbo → tsc strict in every package
bun run build                     # turbo build

# local Postgres (port 5432 may be taken by another project → use DB_PORT)
DB_PORT=5433 docker compose up -d db

# migrations (from apps/api; drizzle-kit)
DATABASE_URL=postgres://subflow:subflow@localhost:5433/subflow bun run db:migrate
bun run db:generate               # after editing src/db/schema.ts

# run the API (from apps/api) — SWC runner, NOT tsx (see gotchas)
DATABASE_URL=... bun run dev      # :3000, GET /health
# without DATABASE_URL the app still boots; DB and pg-boss self-disable

# infra (standalone bun project, NOT a workspace)
cd infra && bun install && bun run synth
```

CI (`.github/workflows/ci.yml`): `check` (lint + typecheck + migrate-from-scratch against a Postgres service), `image` (docker build), `infra` (tsc + cdk synth). Deploy step is gated until the AWS account exists.

## Architecture

Monorepo (bun workspaces + turborepo): `apps/api` (NestJS), `apps/mobile` (Flutter, Phase 3), `packages/shared` (domain enums mirrored by pg enums), `packages/detection` (detection engine as a **pure library** so the offline eval can run it without Nest), `infra/` (AWS CDK v2, deliberately outside the workspace so aws-cdk-lib never enters the API docker image).

**One process, two roles:** the NestJS API and pg-boss job queue run in the same Fargate task, sharing one Postgres (no Redis). Jobs (backfill subF-9, webhook consumer subF-10, watchdog) register queues in `JobsModule`.

**Bank access is provider-agnostic:** everything goes through the `BankProvider` interface (`apps/api/src/bank/bank-provider.ts`) with typed errors — 403 → `TokenRevokedError` (connection flips to `revoked` via `ConnectionsService.withConnectionToken`), 429 → `RateLimitedError`. `MonoPersonalProvider` is the MVP implementation; the signed provider API (subF-20) and open banking plug in behind the same interface.

**Rate limiting is central and DB-backed:** mono allows 1 req/60s per token. `provider_rate_leases` holds one row per connection; `acquireProviderLease` claims it with a single atomic conditional UPDATE, which stays correct across concurrent jobs and multiple API tasks. Callers that lose get `retryAfterMs` and must reschedule — never drop work, never call mono without a lease.

**Auth:** magic-link (email via a `Mailer` port — `SesMailer` prod / `LogMailer` dev; `MAIL_TRANSPORT=log` throws in production). Only sha256 hashes of magic-link/refresh tokens are stored. Refresh rotation with reuse detection: presenting a rotated token revokes the user's whole session set. `DELETE /me` is a hard delete relying on FK cascades (magic-link tokens are email-keyed and deleted explicitly; the global merchants catalog survives).

**Schema/migrations:** `apps/api/src/db/schema.ts` is the source of truth; `drizzle-kit generate` diffs it against `drizzle/meta/*_snapshot.json` and emits plain SQL into `apps/api/drizzle/` (the SQL is what runs; the JSON is generator bookkeeping — never edit `meta/` by hand, never edit an already-applied migration). `transactions` keeps Berlin-Group-mappable semantics (mapping note in README); tx id = mono id = natural dedup PK, and `upsertTransaction` is idempotent on it. The pg_trgm GIN index on `transactions.description` powers merchant fuzzy-matching.

**Config:** zod-validated env in `apps/api/src/config/env.ts` (`loadEnv()`, DI token `ENV`). Optional `DATABASE_URL` is a feature: the skeleton boots without a DB. `MONO_BASE_URL` is overridable to point at a local mock server for live verification.

## Gotchas (each of these broke the build once)

- **Dev runtime must be SWC** (`node -r @swc-node/register`), not tsx — esbuild does not emit the decorator metadata NestJS DI needs.
- **Biome's `useImportType` is disabled on purpose**: converting injected-class imports to `import type` erases DI metadata and breaks Nest at runtime. Keep value imports for anything injected. Also: `biome.json` allows no comments (strict JSON), and `.turbo` must stay in its ignore list.
- **Do not add `infra` to root workspaces** — the API image build fails with "Workspace not found infra".
- **Dockerfile copies the whole pruned tree** (`bun install --production` then `COPY /repo`): bun scatters deps across root and per-package `node_modules`, so selective copying loses packages (e.g. reflect-metadata).
- turbo strict env mode strips env vars from tasks — declare them in `turbo.json` (`env`) if a task needs them.
- Binaries land in per-package `node_modules/.bin` (not hoisted), e.g. tsx/cdk.

## AWS / infra context

CDK v2, region `eu-central-1`, four stacks (Network / Data / App / Ops) in `infra/stacks/`. Cost guardrails are deliberate: no NAT gateway (public subnets + public task IP), single-AZ RDS `t4g.micro`, Fargate 0.25/0.5, $55/mo budget alarm as code. `cdk deploy` and real SES delivery are blocked on external items (dedicated AWS account, subflow.app domain registration) — code is written and `cdk synth` must stay green. HTTPS/ACM/Route53 wiring is a TODO in `stacks/app.ts` gated on the domain.
