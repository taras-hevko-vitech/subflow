import 'package:flutter/material.dart';

import '../../core/api/models.dart';
import '../../theme.dart';

/// Merchant avatar: seed logo when we have one, else a colored initial.
class MerchantAvatar extends StatelessWidget {
  const MerchantAvatar({super.key, required this.merchant, this.radius = 22});
  final MerchantView merchant;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (merchant.logoUrl != null && merchant.logoUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(merchant.logoUrl!));
    }
    final letter = merchant.displayName.isEmpty ? '?' : merchant.displayName.characters.first.toUpperCase();
    final hue = (merchant.displayName.hashCode % 360).abs().toDouble();
    return CircleAvatar(
      radius: radius,
      backgroundColor: HSLColor.fromAHSL(1, hue, 0.45, 0.55).toColor(),
      child: Text(letter, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: radius * 0.8)),
    );
  }
}

/// Subscription row per the aha-screen mockup: avatar · name + "щомісяця · 12 числа" ·
/// amount + a right-side pill ("через 3 дні" / "завтра" / "нова").
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({super.key, required this.sub, required this.onTap});
  final SubscriptionView sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            MerchantAvatar(merchant: sub.merchant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.merchant.displayName, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_subtitle(), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (_extraBadges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: _extraBadges),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(sub.amountMinor, currencyCode: sub.currencyCode),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _StatusPill(sub: sub),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _cadence => switch (sub.cadence) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };

  String _subtitle() {
    final next = sub.nextChargeAt;
    if (next == null || sub.lapsed) return _cadence;
    return '$_cadence · ${next.day} числа';
  }

  List<Widget> get _extraBadges {
    final out = <Widget>[];
    if (sub.badges.increased) out.add(const _Badge('подорожчала'));
    if (sub.badges.container) out.add(const _Badge('Apple/Google'));
    return out;
  }
}

/// The right-side chip: urgency ("завтра", "через 3 дні"), novelty ("нова") or nothing.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.sub});
  final SubscriptionView sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subflow = theme.extension<SubflowColors>();
    final days = sub.daysToCharge;

    String? label;
    Color? bg;
    Color? fg;
    if (sub.lapsed) {
      label = 'заснула';
      bg = theme.colorScheme.surfaceContainerHigh;
      fg = theme.colorScheme.onSurfaceVariant;
    } else if (days != null && days <= 7) {
      label = switch (days) { 0 => 'сьогодні', 1 => 'завтра', _ => 'через $days дн.' };
      bg = subflow?.warningContainer;
      fg = subflow?.onWarningContainer;
    } else if (sub.isNew) {
      label = 'нова';
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.onPrimaryContainer;
    }
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
