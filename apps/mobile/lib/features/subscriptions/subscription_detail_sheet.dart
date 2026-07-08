import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../widgets/widgets.dart';
import 'subscription_actions.dart';
import 'subscription_card.dart';

/// Bottom sheet with charge/price history, yearly cost, how-to-cancel, and a "not a
/// subscription" reject. Opened by tapping a card on the aha screen.
class SubscriptionDetailSheet extends ConsumerWidget {
  const SubscriptionDetailSheet({super.key, required this.id});
  final String id;

  static Future<void> show(BuildContext context, String id) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SubscriptionDetailSheet(id: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subscriptionDetailProvider(id));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scroll) => detail.when(
        loading: () => const SizedBox(height: 240, child: LoadingView()),
        error: (e, _) => SizedBox(height: 240, child: ErrorView(message: 'Не вдалось завантажити', onRetry: () => ref.invalidate(subscriptionDetailProvider(id)))),
        data: (d) => _Body(detail: d, scroll: scroll),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.scroll});
  final SubscriptionDetail detail;
  final ScrollController scroll;

  Future<void> _openCancel(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    await ref.read(subscriptionActionsProvider).reject(detail.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final priceEvents = detail.events.where((e) => e.type == 'price_increase').toList();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Row(
          children: [
            MerchantAvatar(merchant: detail.merchant, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.merchant.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${formatMoney(detail.amountMinor)} · ${_cadence(detail.cadence)}', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Fact(label: 'за рік', value: formatMoney(detail.yearlyEqMinor)),
              _Fact(label: 'з нами від', value: _date(detail.firstSeen)),
              if (detail.nextChargeAt != null) _Fact(label: 'наступне', value: _date(detail.nextChargeAt!)),
            ],
          ),
        ),
        if (detail.status == 'container') ...[
          const SizedBox(height: 16),
          AppCard(
            child: Text(
              'Це агрегат ${detail.merchant.displayName}: усередині можуть бути кілька сервісів. '
              'Розбити на конкретні підписки поки не можемо — подивись список у налаштуваннях ${detail.merchant.displayName}.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
        if (priceEvents.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Зміни ціни', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final e in priceEvents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.trending_up, color: Colors.orange),
              title: Text('${formatMoney(e.oldAmount ?? 0)} → ${formatMoney(e.newAmount ?? 0)}'),
              subtitle: Text(_date(e.at)),
            ),
        ],
        const SizedBox(height: 20),
        Text('Як скасувати', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          detail.merchant.cancelInstructions ?? 'Скасувати можна в застосунку або на сайті сервісу.',
          style: theme.textTheme.bodyMedium,
        ),
        if (detail.merchant.cancelUrl != null && detail.merchant.cancelUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openCancel(detail.merchant.cancelUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Відкрити сторінку скасування'),
          ),
        ],
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => _reject(context, ref),
          icon: const Icon(Icons.block),
          label: const Text('Це не підписка'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        ),
      ],
    );
  }

  String _cadence(String c) => switch (c) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
