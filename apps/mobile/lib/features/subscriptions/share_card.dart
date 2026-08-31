import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/models.dart';

/// Renders a summary card off-screen, captures it to PNG, and opens the share sheet.
/// Amounts are HIDDEN by default (opt-in) — the count + yearly total are the hook.
Future<void> shareSummary(BuildContext context, SubscriptionsSummary summary, {required bool showAmounts}) async {
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context);

  // mount the card off-screen so it lays out and paints, capture, then remove
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -2000,
      child: RepaintBoundary(
        key: boundaryKey,
        child: _ShareCardBody(summary: summary, showAmounts: showAmounts),
      ),
    ),
  );
  overlay.insert(entry);
  await WidgetsBinding.instance.endOfFrame;

  try {
    final render = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) return;
    final image = await render.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final file = XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: 'subflow.png');
    await SharePlus.instance.share(ShareParams(files: [file], text: 'Порахував свої підписки в Subflow 👀'));
  } finally {
    entry.remove();
  }
}

class _ShareCardBody extends StatelessWidget {
  const _ShareCardBody({required this.summary, required this.showAmounts});
  final SubscriptionsSummary summary;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    // brand palette (design system 01) — the card renders off-screen, theme-independent
    const violet = Color(0xFF6B5CE7);
    const ink = Color(0xFF231A66);
    const cream = Color(0xFFFFF6EC);
    const coral = Color(0xFFFF7A59);

    final live = summary.items.where((s) => !s.lapsed).toList()..sort((a, b) => b.yearlyEqMinor - a.yearlyEqMinor);
    final top = live.take(2).toList();
    final restCount = live.length - top.length;
    final restYearly = live.skip(2).fold(0, (sum, s) => sum + s.yearlyEqMinor);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 1080,
        padding: const EdgeInsets.all(72),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [violet, ink], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('subflow', style: TextStyle(color: cream, fontSize: 44, fontWeight: FontWeight.w800)),
            const SizedBox(height: 56),
            const Text('Мої підписки з\'їдають', style: TextStyle(color: cream, fontSize: 48)),
            if (showAmounts) ...[
              Text(formatMoney(summary.totalYearlyMinor),
                  style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w800, height: 1.1)),
              const Text('на рік 🤯', style: TextStyle(color: cream, fontSize: 48)),
            ] else
              Text('${summary.items.length} підписок 🤯',
                  style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 48),
            if (showAmounts) ...[
              for (final s in top) _row(s.merchant.displayName, formatMoney(s.yearlyEqMinor)),
              if (restCount > 0) _row('+ ще $restCount', formatMoney(restYearly)),
              const SizedBox(height: 48),
            ],
            const Text('А скільки з\'їдають твої? → subflow.app',
                style: TextStyle(color: coral, fontSize: 36, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _row(String name, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 40), overflow: TextOverflow.ellipsis)),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// Opt-in dialog before sharing: choose whether to reveal the amount.
Future<void> promptShare(BuildContext context, SubscriptionsSummary summary) async {
  final choice = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Що показати у картинці?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ListTile(
            leading: const Icon(Icons.visibility_off),
            title: const Text('Тільки кількість підписок'),
            subtitle: const Text('Суми приховані'),
            onTap: () => Navigator.pop(ctx, false),
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Показати й суму за рік'),
            onTap: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice != null && context.mounted) await shareSummary(context, summary, showAmounts: choice);
}
