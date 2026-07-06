# subF-18 · Дистрибуція: TestFlight/Internal + аналітика релізу
**Фаза:** 4 · **Розмір:** S · **Блокери:** subF-13..subF-17

## Задачі
- [ ] Apple Developer Program ($99/рік, **individual** — юрособи немає) — оформити заздалегідь, активація може тривати днями
- [ ] iOS: bundle id, сертифікати/профілі, збірка → TestFlight internal (миттєво) → external (проходить полегшене рев'ю — заклади 1–3 дні; фінтех можуть дивитись уважніше: privacy policy і опис доступу до даних мають бути готові, subF-17)
- [ ] Android: Google Play Console ($25), internal testing track; альтернативно — пряма роздача APK першим користувачам
- [ ] Fastlane для збірок обох платформ (не обов'язково, але окупиться на 3-й ітерації)
- [ ] PostHog: фінальна перевірка воронки (install → auth → connect → aha → D1/D7 return), дашборд ключових метрик
- [ ] Sentry release tracking + sourcemaps/symbols

## Acceptance Criteria
Зовнішній тестер ставить застосунок за лінком без твоєї участі; всі кроки воронки видно в PostHog; крашрепорти символіковані.
