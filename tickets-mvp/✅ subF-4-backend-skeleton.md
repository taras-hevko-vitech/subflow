# subF-4 · Каркас бекенду + CI/CD
**Фаза:** 1 · **Розмір:** S · **Блокери:** немає

## Задачі
- [ ] Монорепо (turborepo): `apps/api`, `apps/mobile`, `packages/shared` (типи/DTO), `packages/detection` (рушій як окрема бібліотека), `infra/` (CDK — див. subF-5)
- [ ] NestJS: конфіг-модуль (env-валідація), class-validator, глобальний exception filter, health-check `/health`
- [ ] PostgreSQL + Drizzle ORM + drizzle-kit міграції (plain SQL)
- [ ] pg-boss: модуль черг у тому ж процесі, приклад джоби
- [ ] Sentry (api), структуровані логи (pino); ПРАВИЛО: токени/виписки ніколи не логуються (redaction)
- [ ] Dockerfile (multi-stage) для образу у ECR; docker-compose (api + postgres) ЛИШЕ для локальної розробки
- [ ] CI (GitHub Actions): lint + test + build image → push у ECR → deploy (ECS service update / `cdk deploy`). Deploy-крок вмикається, коли з'явиться AWS-акаунт (subF-5); до того — до кроку build+push
- [ ] OpenAPI (Swagger) увімкнений — з нього генеруються типи для Flutter (subF-13)

## Acceptance Criteria
`docker compose up` локально піднімає api+postgres; CI зелений (lint+test+build+push образу в ECR); `/health` зелений локально; Sentry ловить тестову помилку. Прод-деплой перевіряється в subF-5 після створення акаунта.
