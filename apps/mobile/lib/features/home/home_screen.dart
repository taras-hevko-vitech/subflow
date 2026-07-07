import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

/// Dispatcher: no active connection → connect CTA (→ onboarding); connected → the aha view
/// (basic here; polished in subF-15) with a banner while the backfill is still running.
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
            icon: const Icon(Icons.logout),
            tooltip: 'Вийти',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
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
            return _SubscriptionsView(backfillDone: active.first.backfill.done);
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

class _SubscriptionsView extends ConsumerWidget {
  const _SubscriptionsView({required this.backfillDone});
  final bool backfillDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subs = ref.watch(subscriptionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(subscriptionsProvider);
        ref.invalidate(connectionsProvider);
      },
      child: subs.when(
        loading: () => const LoadingView(),
        error: (e, _) => ListView(children: [ErrorView(message: 'Помилка', onRetry: () => ref.invalidate(subscriptionsProvider))]),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!backfillDone)
              AppCard(
                child: Row(
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Ще аналізуємо старіші місяці…', style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // The aha number — subF-15 turns this into the hero moment.
            Center(
              child: Column(
                children: [
                  Text(formatMoney(summary.totalMonthlyMinor), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('на місяць', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${formatMoney(summary.totalYearlyMinor)} на рік', style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final s in summary.items) _SubTile(sub: s),
            if (summary.items.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 40), child: EmptyView(title: 'Підписок не знайдено')),
          ],
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({required this.sub});
  final SubscriptionView sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(sub.merchant.displayName.characters.first)),
      title: Text(sub.merchant.displayName),
      subtitle: Text(_cadence(sub.cadence)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatMoney(sub.amountMinor), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (sub.isContainer) Text('контейнер', style: theme.textTheme.labelSmall),
          if (sub.needsConfirm) Text('підтверди?', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary)),
        ],
      ),
    );
  }

  String _cadence(String c) => switch (c) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };
}
