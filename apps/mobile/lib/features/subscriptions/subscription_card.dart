import 'package:flutter/material.dart';

import '../../core/api/models.dart';

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

class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({super.key, required this.sub, required this.onTap});
  final SubscriptionView sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
                  Text(_subtitle(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (_badges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: _badges),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(sub.amountMinor), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(_cadence, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
    if (next == null) return sub.merchant.isSeed ? 'сервіс' : '';
    return 'наступне: ${next.day.toString().padLeft(2, '0')}.${next.month.toString().padLeft(2, '0')}';
  }

  List<Widget> get _badges {
    final out = <Widget>[];
    if (sub.badges.increased) out.add(const _Badge('подорожчала', Colors.orange));
    if (sub.badges.old) out.add(const _Badge('давня', Colors.blueGrey));
    if (sub.badges.container) out.add(const _Badge('Apple/Google', Colors.grey));
    return out;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
