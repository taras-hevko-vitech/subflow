# subF-2 · Заявка на provider API monobank
**Фаза:** 0 · **Розмір:** S · **Блокери:** бажано після subF-1 · **Пріоритет:** високий (найдовший час дозрівання)

## Мета
Подати заявку якнайраніше — розгляд ітиме паралельно з розробкою.

## Задачі
- [ ] Згенерувати ключі: `openssl ecparam -genkey -name secp256k1 -out priv.pem && openssl ec -in priv.pem -pubout -out pub.pem`
- [ ] Приватний ключ → у AWS Secrets Manager (не в репо!)
- [ ] Підготувати: назву (Subflow), опис (конкретно: PFM/трекер підписок, потрібні client-info + statement, дані лише за згодою клієнта), контактну особу, телефон, email, лого (base64)
- [ ] Уточнити юрформу за результатом subF-1 (зараз юрособи/ФОП немає)
- [ ] Реалізувати мінімальний скрипт підпису X-Sign (X-Time | URL, ECDSA secp256k1, base64) для запиту реєстрації
- [ ] `POST /personal/auth/registration` → очікувати `{"status":"New"}`
- [ ] Періодичний чек: `POST /personal/auth/registration/status` (нагадування раз на кілька днів) до `Approved` + отримання keyId

## Acceptance Criteria
Заявка подана, статус відстежується; keyId зафіксований після апруву.

## Нотатки
Специфікація: api.monobank.ua/docs/corporate.html; community-доки: github.com/andrew-demb/monobank-api-community-docs (gist з алгоритмом X-Sign + OpenAPI spec).
