# subF-6 · Auth (magic link, SES) + акаунти
**Фаза:** 1 · **Розмір:** S · **Блокери:** subF-4

## Задачі
- [ ] Таблиця `users` (id, email unique, created_at, onboarding_state)
- [ ] Magic link: `POST /auth/request` (email → одноразовий токен, TTL 15 хв, rate limit) → лист через AWS SES (домен subflow.app, DKIM) → `POST /auth/verify` → JWT access (15 хв) + refresh (30 днів, ротація)
- [ ] Deep link для мобілки: universal link `https://subflow.app/auth?token=...` (+ `app://` фолбек) — узгодити з subF-13
- [ ] `device_tokens` (user_id, fcm/apns token, platform) + ендпоінт реєстрації
- [ ] `DELETE /me` — hard delete усіх даних користувача (users, connections, transactions, subscriptions) — фіча довіри, робимо одразу
- [ ] Guard-и NestJS, декоратор @CurrentUser

## Acceptance Criteria
Повний цикл email→link→JWT працює (лист через SES доходить); refresh ротуються; hard delete підтверджено тестом (нуль рядків після видалення).
