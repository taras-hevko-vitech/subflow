# subF-13 · Каркас Flutter-застосунку
**Фаза:** 3 · **Розмір:** S · **Блокери:** subF-6 (auth-контракт)

## Задачі
- [ ] Flutter-проєкт у монорепо (apps/mobile); flavors dev/prod
- [ ] Роутинг go_router; стан **Riverpod** (зафіксовано в ТЗ)
- [ ] HTTP-клієнт (dio) + інтерсептор JWT/refresh; генерація API-типів з OpenAPI бекенду (openapi-generator) — контракт не розповзається
- [ ] Auth-флоу: екран email → «перевір пошту» → universal link (`https://subflow.app/auth?...`) → сесія у secure storage
- [ ] Firebase: FCM (Android) + APNs (iOS), запит дозволу, реєстрація device token на бекенді (subF-6)
- [ ] Sentry Flutter + PostHog SDK (базові івенти: app_open, auth_completed)
- [ ] Дизайн-мінімум: тема, типографіка, 8-10 базових компонентів (кнопка, картка, лоадер, empty state)

## Acceptance Criteria
Логін через magic link працює на реальних iOS+Android девайсах; тестовий пуш доходить на обидві платформи; краш ловиться Sentry.
