import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/subflow_api.dart';
import '../../widgets/widgets.dart';
import '../subscriptions/subscriptions_view.dart';

/// Dispatcher: no active connection → connect CTA (→ onboarding); connected → the aha screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subflow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Профіль',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: connections.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Не вдалось завантажити', onRetry: () => ref.invalidate(connectionsProvider)),
          data: (list) {
            final active = list.where((c) => c.isActive).toList();
            if (active.isEmpty) return _ConnectCta(revoked: list.any((c) => !c.isActive));
            return SubscriptionsView(backfillDone: active.first.backfill.done);
          },
        ),
      ),
    );
  }
}

class _ConnectCta extends StatelessWidget {
  const _ConnectCta({required this.revoked});
  final bool revoked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(revoked ? 'Доступ до monobank втрачено' : 'Підключи monobank',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(revoked ? 'Перепідключи, щоб знову бачити підписки.' : 'Займе хвилину. Далі Subflow усе зробить сам.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryButton(label: revoked ? 'Перепідключити' : 'Підключити monobank', onPressed: () => context.go('/onboarding')),
        ],
      ),
    );
  }
}
