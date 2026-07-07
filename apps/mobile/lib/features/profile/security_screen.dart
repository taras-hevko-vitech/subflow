import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Static trust screen (subF-17): what we store / never store, encryption, revoke steps.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Безпека і приватність')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Section(
              icon: Icons.visibility_off,
              title: 'Тільки читаємо',
              body: 'Subflow має доступ лише на читання виписки. Ми не можемо переказувати гроші, '
                  'відкривати рахунки чи щось міняти у твоєму monobank.',
            ),
            _Section(
              icon: Icons.lock,
              title: 'Токен зашифрований',
              body: 'Твій API-токен зберігається зашифрованим (AES-256-GCM). Ключ шифрування '
                  'ніколи не лежить поруч із даними. Пароля від monobank ми не бачимо взагалі.',
            ),
            _Section(
              icon: Icons.receipt_long,
              title: 'Що зберігаємо',
              body: 'Знеособлені транзакції (сума, час, мерчант, MCC) — щоб знаходити підписки. '
                  'Ми не зберігаємо CVV, PIN чи повний номер картки.',
            ),
            _Section(
              icon: Icons.key_off,
              title: 'Як відкликати доступ',
              body: 'У будь-який момент зайди на api.monobank.ua і видали токен — Subflow одразу '
                  'втратить доступ. А кнопкою «Видалити акаунт» зітреш і всі дані в нас.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.push('/privacy'), child: const Text('Політика приватності')),
            const SizedBox(height: 12),
            Text(
              'Subflow надає аналітику твоїх витрат і не є надавачем платіжних послуг.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
