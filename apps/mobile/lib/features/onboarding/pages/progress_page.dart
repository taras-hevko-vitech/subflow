import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics.dart';
import '../../../core/api/models.dart';
import '../../../core/api/subflow_api.dart';
import '../../../widgets/widgets.dart';
import '../onboarding_controller.dart';

/// Step 5 — backfill progress (design "Анімації" §2): three layers of life while the
/// user waits up to ~50 min. Weeks fill with a soft overshoot, the current week
/// breathes, calm messages rotate. Newest ~2 months land first, so partial results
/// appear within minutes; the user can leave and get a push when it's done.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key, required this.connectionId, required this.onDone});
  final String connectionId;
  final VoidCallback onDone;

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  Timer? _rotate;
  int _msgIndex = 0;

  static const _reassurance = [
    'Банк віддає історію частинами — це нормально.',
    'Можеш закрити застосунок: надішлемо пуш, коли все буде готово.',
    'Читаємо виписку в режимі read-only. Тільки читання, нічого більше.',
    'Що більше історії — то точніше знайдемо всі підписки.',
  ];

  @override
  void initState() {
    super.initState();
    _rotate = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _msgIndex++);
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    super.dispose();
  }

  String _message(List<SubscriptionView> found) {
    // interleave live finds with reassurance: found names make the wait feel productive
    final pool = [
      for (final s in found.take(4)) 'Знайшли ${s.merchant.displayName} у виписці 👀',
      ..._reassurance,
    ];
    return pool[_msgIndex % pool.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(backfillProgressProvider(widget.connectionId));
    final partial = ref.watch(subscriptionsProvider);

    final p = progress.value;
    final done = p?.done ?? false;
    final total = p?.totalWindows ?? 0;
    final completed = p?.completedWindows ?? 0;
    final percent = p == null ? 0 : (p.fraction * 100).round();
    final minutesLeft = total > completed ? total - completed : 0; // ~1 window/min (mono rate limit)
    final found = partial.value?.items ?? const <SubscriptionView>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(done ? 'Готово 🎉' : 'Читаємо виписку\nза 12 місяців', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              done
                  ? 'Виписку оброблено. Подивись, чи всі підписки впізнаєш.'
                  : 'Банк віддає історію частинами, тож це триває до ~50 хв. Можеш закрити застосунок — надішлемо пуш, коли все буде готово.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // the percent ticks smoothly, it never jumps
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent.toDouble()),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text('${v.round()}%', style: theme.textTheme.headlineLarge),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    done ? 'всі $total' : '$completed із $total · ~$minutesLeft хв лишилось',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WeeksGrid(completed: completed, total: total == 0 ? 52 : total),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                done ? 'Знайшли ${found.length} підписок.' : _message(found),
                key: ValueKey(done ? -1 : _msgIndex),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            if (found.isNotEmpty) ...[
              Text('ВЖЕ ЗНАЙДЕНО', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.2)),
              const SizedBox(height: 8),
            ],
            Expanded(child: _Partial(summary: partial.value, loading: partial.isLoading)),
            PrimaryButton(
              label: done ? 'Переглянути підписки' : 'Згорнути — сповістимо, коли готово',
              onPressed: () {
                if (done) Analytics.firstSubscriptions(found.length);
                widget.onDone();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Weeks tiles: processed ones pop in with a soft overshoot, the current one breathes.
class _WeeksGrid extends StatefulWidget {
  const _WeeksGrid({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  State<_WeeksGrid> createState() => _WeeksGridState();
}

class _WeeksGridState extends State<_WeeksGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < widget.total; i++)
            if (i < widget.completed)
              TweenAnimationBuilder<double>(
                key: ValueKey('w$i'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, t, _) => Transform.scale(
                  scale: t,
                  child: _tile(scheme.primary),
                ),
              )
            else if (i == widget.completed)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_pulse.value);
                  return _tile(Color.lerp(scheme.primaryContainer, scheme.primary, 1 - t)!);
                },
              )
            else
              _tile(scheme.surfaceContainerHigh),
        ],
      ),
    );
  }

  Widget _tile(Color color) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      );
}

class _Partial extends StatelessWidget {
  const _Partial({required this.summary, required this.loading});
  final SubscriptionsSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (summary == null && loading) return const LoadingView();
    final items = summary?.items ?? const <SubscriptionView>[];
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Row(
        children: [
          Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('Шукаємо далі…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = items[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(s.merchant.displayName.characters.first)),
          title: Text(s.merchant.displayName),
          subtitle: Text('${formatMoney(s.amountMinor, currencyCode: s.currencyCode)} · ${_cadence(s.cadence)}'),
          trailing: s.isContainer ? Chip(label: const Text('контейнер'), backgroundColor: theme.colorScheme.surfaceContainerHighest) : null,
        );
      },
    );
  }

  String _cadence(String c) => switch (c) { 'weekly' => 'щотижня', 'yearly' => 'щороку', _ => 'щомісяця' };
}
