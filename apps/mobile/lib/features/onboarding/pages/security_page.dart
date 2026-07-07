import 'package:flutter/material.dart';

import '../../../widgets/widgets.dart';

/// Step 2 — trust. What we store / never store; read-only; token revocable anytime.
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('Твої дані — під замком', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const _Point(icon: Icons.visibility_off, text: 'Ми лише читаємо виписку. Не можемо переказувати гроші чи щось міняти.'),
            const _Point(icon: Icons.lock, text: 'Токен зберігається зашифрованим. Ми ніколи не бачимо твій пароль від monobank.'),
            const _Point(icon: Icons.key_off, text: 'Доступ можна відкликати будь-коли в кабінеті monobank — одним дотиком.'),
            const _Point(icon: Icons.delete_forever, text: 'Видалиш акаунт — зітремо всі твої дані назавжди.'),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('Політика приватності')),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Зрозуміло, далі', onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
