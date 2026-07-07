import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../widgets/widgets.dart';
import 'share_card.dart';
import 'subscription_actions.dart';
import 'subscription_card.dart';
import 'subscription_detail_sheet.dart';

/// The aha screen (subF-15): the big ₴/month + ₴/year, a "confirm me" section for the
/// 0.5–0.8 tier, then the full list sorted by cost. This screen sells the product.
class SubscriptionsView extends ConsumerWidget {
  const SubscriptionsView({super.key, required this.backfillDone});
  final bool backfillDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(subscriptionsProvider);
        ref.invalidate(connectionsProvider);
        await ref.read(subscriptionsProvider.future);
      },
      child: subs.when(
        loading: () => const LoadingView(),
        error: (e, _) => ListView(children: [const SizedBox(height: 120), ErrorView(message: 'Помилка', onRetry: () => ref.invalidate(subscriptionsProvider))]),
        data: (summary) => _Content(summary: summary, backfillDone: backfillDone),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.summary, required this.backfillDone});
  final SubscriptionsSummary summary;
  final bool backfillDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmable = summary.items.where((s) => s.needsConfirm).toList();
    final confirmed = summary.items.where((s) => !s.needsConfirm).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        if (!backfillDone) _AnalyzingBanner(),
        _Hero(summary: summary),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: summary.items.isEmpty ? null : () => promptShare(context, summary),
            icon: const Icon(Icons.ios_share),
            label: const Text('Поділитись'),
          ),
        ),
        const SizedBox(height: 16),
        if (confirmable.isNotEmpty) ...[
          Text('Схоже на підписку — підтверди', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final s in confirmable) _ConfirmTile(sub: s),
          const Divider(height: 32),
        ],
        if (confirmed.isNotEmpty)
          Text('Твої підписки', style: Theme.of(context).textTheme.titleMedium),
        for (final s in confirmed) SubscriptionCard(sub: s, onTap: () => SubscriptionDetailSheet.show(context, s.id)),
        if (summary.items.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: EmptyView(title: 'Підписок не знайдено', subtitle: 'Якщо бекфіл ще йде — зачекай трохи.')),
      ],
    );
  }
}

/// The hero number counts up on first paint — the moment that sells the product.
class _Hero extends StatelessWidget {
  const _Hero({required this.summary});
  final SubscriptionsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: summary.totalMonthlyMinor.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            formatMoney(value.round()),
            style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, height: 1),
          ),
        ),
        Text('на місяць', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Text('${formatMoney(summary.totalYearlyMinor)} на рік', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _AnalyzingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text('Ще аналізуємо старіші місяці — список зростатиме.', style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// 0.5–0.8 tier: one-tap confirm / reject. Optimistic — the list re-fetches after.
class _ConfirmTile extends ConsumerWidget {
  const _ConfirmTile({required this.sub});
  final SubscriptionView sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(subscriptionActionsProvider);
    return Dismissible(
      key: ValueKey('confirm-${sub.id}'),
      background: _swipeBg(context, Alignment.centerLeft, Icons.check, Colors.green, 'Так'),
      secondaryBackground: _swipeBg(context, Alignment.centerRight, Icons.close, Colors.red, 'Ні'),
      onDismissed: (dir) => dir == DismissDirection.startToEnd ? actions.confirm(sub.id) : actions.reject(sub.id),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(child: SubscriptionCard(sub: sub, onTap: () => SubscriptionDetailSheet.show(context, sub.id))),
              IconButton(icon: const Icon(Icons.close), color: Colors.red, onPressed: () => actions.reject(sub.id)),
              IconButton(icon: const Icon(Icons.check), color: Colors.green, onPressed: () => actions.confirm(sub.id)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swipeBg(BuildContext context, Alignment align, IconData icon, Color color, String label) {
    return Container(
      color: color.withValues(alpha: 0.15),
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color))]),
    );
  }
}
