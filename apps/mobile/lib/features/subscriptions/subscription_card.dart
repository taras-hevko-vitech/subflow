import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/models.dart';

/// Merchant avatar per the mockup: a 44dp rounded square (radius 13) with a colored
/// background and a Rubik-800 initial; seed logo image when we have one.
class MerchantAvatar extends StatelessWidget {
  const MerchantAvatar({super.key, required this.merchant, this.size = 44});
  final MerchantView merchant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 13 / 44);
    if (merchant.logoUrl != null && merchant.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(merchant.logoUrl!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    final letter = merchant.displayName.isEmpty ? '?' : merchant.displayName.characters.first.toUpperCase();
    final hue = (merchant.displayName.hashCode % 360).abs().toDouble();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor(), borderRadius: radius),
      alignment: Alignment.center,
      child: Text(letter, style: GoogleFonts.rubik(fontSize: size * 19 / 44, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

/// Subscription card per the mockup: white tile (radius 18, feather shadow), avatar,
/// Rubik-600 title + "щомісяця · 12 числа", Rubik-700 amount + a status pill.
/// [flat] drops the tile decoration for embedding (confirm tiles).
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({super.key, required this.sub, required this.onTap, this.flat = false});
  final SubscriptionView sub;
  final VoidCallback onTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final row = Row(
      children: [
        MerchantAvatar(merchant: sub.merchant),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub.merchant.displayName,
                  style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(_subtitle(),
                  style: GoogleFonts.golosText(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatMoney(sub.amountMinor, currencyCode: sub.currencyCode),
                style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            if (_pill(theme) case final pill?) ...[const SizedBox(height: 4), pill],
          ],
        ),
      ],
    );

    if (flat) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: row));
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: isLight ? null : Border.all(color: theme.colorScheme.outline, width: 0.5),
          boxShadow: isLight
              ? const [BoxShadow(color: Color(0x0F2B2440), offset: Offset(0, 2), blurRadius: 8)]
              : null,
        ),
        child: row,
      ),
    );
  }

  String get _cadence => switch (sub.cadence) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };

  String _subtitle() {
    final next = sub.nextChargeAt;
    var line = (next == null || sub.lapsed) ? _cadence : '$_cadence · ${next.day} числа';
    if (sub.badges.increased) line += ' · подорожчала';
    if (sub.badges.container) line += ' · Apple/Google';
    return line;
  }

  /// Mockup pills: amber urgency ("завтра", "через 3 дні"), violet "нова", muted "заснула".
  Widget? _pill(ThemeData theme) {
    final days = sub.daysToCharge;
    final (String, Color, Color)? spec = sub.lapsed
        ? ('заснула', theme.colorScheme.surfaceContainerHigh, theme.colorScheme.onSurfaceVariant)
        : (days != null && days <= 7)
            ? (switch (days) { 0 => 'сьогодні', 1 => 'завтра', _ => 'через $days дн.' }, const Color(0xFFFFEFC9), const Color(0xFF8A5A00))
            : sub.isNew
                ? ('нова', const Color(0xFFE7E2FF), const Color(0xFF4A3DB8))
                : null;
    if (spec == null) return null;
    final (label, bg, fg) = spec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.golosText(fontSize: 10, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}
