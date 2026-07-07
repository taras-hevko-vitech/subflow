# subF-8 · Інтеграція monobank (personal token)
**Фаза:** 1 · **Розмір:** M · **Блокери:** subF-6, subF-7

## Задачі
- [ ] Інтерфейс `BankProvider` (getClientInfo, getStatement(account, from, to), registerWebhook) — provider API/open banking підключаться як інші імплементації
- [ ] Імплементація MonoPersonalProvider: HTTP-клієнт, X-Token header, таймаути, ретраї з бекофом на 5xx
- [ ] `POST /connections/mono/personal` — прийом токена: негайна валідація викликом client-info → збереження зашифрованим → створення accounts → відповідь зі списком рахунків
- [ ] `PATCH /accounts/:id` — вмик/вимик is_tracked
- [ ] Центральний rate-limiter 1 req/60s НА ТОКЕН для statement/client-info: **DB-lease** (рядок `next_allowed_at` на конекшен), обгортка навколо провайдера — коректний навіть при >1 таску (не in-process)
- [ ] Обробка 403 від mono → connection.status='revoked' → подія для пуша «перепідключи» (subF-16)
- [ ] Обробка 429 → пауза, не втрачати джобу

## Acceptance Criteria
Токен підключається ≤10 сек; невалідний токен → зрозуміла помилка; ліміт 1/60s дотримується під конкурентними джобами (інтеграційний тест з фейк-провайдером); 403 переводить у revoked.
