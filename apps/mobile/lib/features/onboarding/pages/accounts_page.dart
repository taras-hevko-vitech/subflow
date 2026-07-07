import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../widgets/widgets.dart';
import '../onboarding_controller.dart';

/// Step 4 — pick accounts to track. FOP accounts default off (noise for detection).
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key, required this.onNext, required this.connectionId});
  final VoidCallback onNext;
  final String? connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(onboardingControllerProvider).accounts;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Які рахунки аналізуємо?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('ФОП-рахунки вимкнені — там забагато робочого шуму.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: accounts.length,
              itemBuilder: (context, i) {
                final a = accounts[i];
                return SwitchListTile(
                  value: a.isTracked,
                  onChanged: (v) => ref.read(onboardingControllerProvider.notifier).toggleAccount(a.id, v),
                  title: Text(_accountTitle(a)),
                  subtitle: Text(a.maskedPan ?? a.id),
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(label: 'Почати аналіз', onPressed: onNext),
          ),
        ],
      ),
    );
  }

  String _accountTitle(BankAccountView a) {
    final kind = switch (a.type) {
      'black' => 'Чорна картка',
      'white' => 'Біла картка',
      'platinum' => 'Platinum',
      'iron' => 'Iron',
      'fop' => 'ФОП',
      _ => a.type ?? 'Рахунок',
    };
    final ccy = a.currencyCode == 980 ? 'UAH' : a.currencyCode.toString();
    return '$kind · $ccy';
  }
}
