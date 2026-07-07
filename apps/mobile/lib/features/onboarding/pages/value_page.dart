import 'package:flutter/material.dart';

import '../../../widgets/widgets.dart';

/// Step 1 — value. One screen, no 5-slide carousel (per the ticket).
class ValuePage extends StatelessWidget {
  const ValuePage({super.key, required this.onNext});
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
            const Spacer(),
            Icon(Icons.receipt_long, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Побач усі свої підписки', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'Subflow сам знаходить регулярні списання у твоєму monobank і показує, '
              'скільки вони їдять на місяць і на рік — разом із тими, про які ти забув.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(flex: 2),
            PrimaryButton(label: 'Далі', onPressed: onNext),
          ],
        ),
      ),
    );
  }
}
