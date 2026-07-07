import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics.dart';
import '../../../core/api/models.dart';
import '../../../core/api/subflow_api.dart';
import '../../../widgets/widgets.dart';
import '../onboarding_controller.dart';

/// Step 5 — backfill progress with PARTIAL RESULTS. Newest ~2 months land first, so
/// subscriptions appear within minutes; the user can leave and get a push when it's done.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key, required this.connectionId, required this.onDone});
  final String connectionId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(backfillProgressProvider(connectionId));
    final partial = ref.watch(subscriptionsProvider);

    final p = progress.value;
    final month = p == null ? 0 : (p.fraction * 12).round().clamp(0, 12);
    final done = p?.done ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(done ? 'Аналіз завершено 🎉' : 'Аналізуємо твою виписку…',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: p?.fraction, minHeight: 10, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 8),
            Text(done ? 'Готово' : 'Місяць $month з 12', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            if (!done)
              Text('Можеш закрити застосунок — надішлемо пуш, коли все буде готово.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text('Вже знайдено', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(child: _Partial(summary: partial.value, loading: partial.isLoading)),
            PrimaryButton(label: done ? 'Переглянути підписки' : 'Показати, що знайшли', onPressed: () {
              if (done) Analytics.firstSubscriptions(partial.value?.items.length ?? 0);
              onDone();
            }),
          ],
        ),
      ),
    );
  }
}

class _Partial extends StatelessWidget {
  const _Partial({required this.summary, required this.loading});
  final SubscriptionsSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (summary == null && loading) return const LoadingView();
    final items = summary?.items ?? const [];
    if (items.isEmpty) {
      return const EmptyView(title: 'Поки нічого', subtitle: 'Свіжі місяці ще підтягуються…');
    }
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = items[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(s.merchant.displayName.characters.first)),
          title: Text(s.merchant.displayName),
          subtitle: Text('${formatMoney(s.amountMinor)} · ${_cadence(s.cadence)}'),
          trailing: s.isContainer ? Chip(label: const Text('контейнер'), backgroundColor: theme.colorScheme.surfaceContainerHighest) : null,
        );
      },
    );
  }

  String _cadence(String c) => switch (c) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };
}
