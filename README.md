# Subflow

Трекер підписок для monobank (Україна). Підключаєш monobank → сервіс автоматично
знаходить регулярні списання → показує «ось твої підписки, ₴/міс і ₴/рік, ось що ти
забув» → шле пуш перед кожним списанням. **Zero manual entry** — детекція з банківських
транзакцій це і є продукт.

Read-only: ми лише читаємо виписки. Банківські токени шифруються (AES-256-GCM), у логи
токени й виписки не потрапляють ніколи.

## Стек

- **Mobile:** Flutter (Riverpod · go_router · dio + типи з OpenAPI) — `apps/mobile` (subF-13+)
- **Backend:** NestJS (strict TS) — `apps/api`
- **DB / черги:** PostgreSQL + pg-boss (без Redis), ORM Drizzle
- **Infra:** AWS (ECS Fargate + RDS + ALB) через CDK v2 — `infra/` (subF-5)
- **Пошта:** SES · **Пуш:** FCM/APNs · **Обсервабіліті:** Sentry + PostHog
- **Тулчейн:** bun (пакет-менеджер) + turborepo · Node 22 рантайм

## Монорепо

```
apps/api            NestJS (HTTP + pg-boss джоби в одному процесі)
apps/mobile         Flutter (subF-13+)
packages/shared     спільні типи/DTO/enum-и (provider, cadence, status)
packages/detection  рушій детекції як чиста бібліотека (subF-11, офлайн-тести subF-12)
infra               AWS CDK v2 (subF-5)
tickets-mvp         беклог (subF-0-INDEX.md — вхідна точка)
```

## Локальна розробка

Потрібно: **Node 22** (`nvm use`), **bun**, **Docker** (для локального Postgres).

```bash
bun install
docker compose up -d db          # локальний Postgres
cd apps/api && bun run dev        # API на :3000, /health
```

Перевірка каркасу: `curl localhost:3000/health` → `{"status":"ok",...}`.

Скрипти (з кореня): `bun run typecheck` · `bun run test` · `bun run lint` · `bun run build`.

## Беклог

Дивись `tickets-mvp/subF-0-INDEX.md` — порядок виконання, залежності, go/no-go гейти.
