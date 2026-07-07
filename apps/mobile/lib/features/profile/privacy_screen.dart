import 'package:flutter/material.dart';

/// Privacy policy + data-processing consent (subF-17). Inline text for the MVP so it ships
/// with TestFlight; a hosted web version replaces it before a public store release.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Хто ми',
      'Subflow — сервіс аналітики особистих фінансів. Ми показуємо твої підписки й регулярні '
          'списання. Ми не є банком і не надаємо платіжних послуг.',
    ),
    (
      'Які дані обробляємо',
      'Email (для входу), API-токен monobank (зашифрований), а також транзакції твоїх '
          'вибраних рахунків: сума, час, назва мерчанта, MCC, баланс. Усе — лише для того, '
          'щоб знаходити підписки й рахувати суми.',
    ),
    (
      'Доступ до банку',
      'Тільки читання. Токен зберігається зашифрованим і використовується виключно для '
          'отримання виписки. Ти можеш відкликати його в кабінеті monobank будь-коли.',
    ),
    (
      'Зберігання і видалення',
      'Дані зберігаються, поки ти користуєшся сервісом. Кнопка «Видалити акаунт» назавжди '
          'стирає всі твої дані з наших систем.',
    ),
    (
      'Твоя згода',
      'Підключаючи monobank, ти погоджуєшся на обробку персональних даних у межах цієї '
          'політики.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Політика приватності')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final (title, body) in _sections) ...[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
