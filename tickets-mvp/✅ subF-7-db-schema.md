# subF-7 · Схема БД (ядро домену, Drizzle)
**Фаза:** 1 · **Розмір:** S · **Блокери:** subF-4

## Задачі
- [ ] `bank_connections`: id, user_id, provider ('mono_personal'|'mono_provider'|майбутні), encrypted_token (AES-256-GCM, ключ з AWS Secrets Manager — НЕ в БД/репо), status ('active'|'revoked'|'error'), backfill_progress jsonb, webhook_registered_at
- [ ] `accounts`: id (mono account id), connection_id, type, currency, masked_pan, is_tracked bool
- [ ] `transactions`: id (mono tx id, PK — природна дедуплікація), account_id, time timestamptz, description text, mcc int, amount bigint (копійки, від'ємні = витрати), currency, raw jsonb; індекси: (account_id, time), GIN по description (pg_trgm) для нормалізації
- [ ] `merchants`: id, canonical_key (norm_name+mcc, unique), display_name, logo_url, cancel_url/instructions, is_seed bool, patterns jsonb
- [ ] `subscriptions`: id, user_id, merchant_id, cadence ('weekly'|'monthly'|'yearly'), amount_minor, currency, confidence numeric, status ('detected'|'confirmed'|'rejected'|'container'), first_seen, last_charge_at, next_charge_at
- [ ] `subscription_events`: subscription_id, type ('charge'|'price_increase'|'missed'), tx_id, old_amount, new_amount, at
- [ ] `detection_feedback`: user_id, subscription_id?, tx_id?, verdict, comment, at
- [ ] Drizzle schema + drizzle-kit міграції (plain SQL); окрема міграція `CREATE EXTENSION pg_trgm`
- [ ] Семантика полів transactions сумісна з Berlin Group (мапінг-нотатка в README)

## Acceptance Criteria
Міграції накатуються з нуля; upsert транзакції по PK ідемпотентний (тест); шифрування/дешифрування токена ключем із Secrets Manager покрито тестом.
