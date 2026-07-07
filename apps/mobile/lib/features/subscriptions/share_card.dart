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
    const w = 1080.0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: w,
        padding: const EdgeInsets.all(72),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2E6BE6), Color(0xFF1B3B8B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subflow', style: TextStyle(color: Colors.white70, fontSize: 40, fontWeight: FontWeight.w700)),
            const SizedBox(height: 60),
            Text('Знайшлось', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 44)),
            Text('${summary.items.length} підписок', style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 40),
            if (showAmounts)
              Text('на ${formatMoney(summary.totalYearlyMinor)} на рік 😱',
                  style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700))
            else
              const Text('а скільки в тебе? 👀', style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700)),
            const SizedBox(height: 60),
            const Text('subflow.app', style: TextStyle(color: Colors.white70, fontSize: 32)),
          ],
        ),
      ),
    );
  }
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
