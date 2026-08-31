import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../core/motion.dart';
import '../../widgets/widgets.dart';
import 'share_card.dart';
import 'subscription_actions.dart';
import 'subscription_card.dart';
import 'subscription_detail_sheet.dart';

enum _Filter { all, soon, fresh }

/// The aha screen (subF-15/23): the big ₴/month + ₴/year, filter chips, a "confirm me"
/// section for the 0.5–0.8 tier, the list sorted by cost, and possibly-cancelled at
/// the bottom. This screen sells the product.
class SubscriptionsView extends ConsumerStatefulWidget {
  const SubscriptionsView({super.key, required this.backfillDone});
  final bool backfillDone;

  @override
  ConsumerState<SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends ConsumerState<SubscriptionsView> {
  // While the backfill is running a new statement window lands roughly every 60s
  // (mono rate limit), so poll: without this the user sits on a stale empty list
  // until they discover pull-to-refresh. AsyncValue keeps the previous data during
  // the refetch (skipLoadingOnRefresh), so there is no visible flicker.
  Timer? _poll;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _syncPolling();
  }

  @override
  void didUpdateWidget(SubscriptionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPolling();
  }

  void _syncPolling() {
    if (widget.backfillDone) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
        ref.invalidate(subscriptionsProvider);
        ref.invalidate(connectionsProvider); // refreshes backfillDone → stops polling when done
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        data: (summary) => _Content(
          summary: summary,
          backfillDone: widget.backfillDone,
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.summary, required this.backfillDone, required this.filter, required this.onFilter});
  final SubscriptionsSummary summary;
  final bool backfillDone;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;

  /// The aha entrance (count-up + cascade) plays once per app session, not every rebuild.
  static bool _entrancePlayed = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final play = !_entrancePlayed && summary.items.isNotEmpty;
    if (play) _entrancePlayed = true;

    final live = summary.items.where((s) => !s.lapsed).toList();
    final lapsed = summary.items.where((s) => s.lapsed).toList();
    final soon = live.where((s) => s.chargesSoon).toList();
    final fresh = live.where((s) => s.isNew).toList();

    final visible = switch (filter) { _Filter.all => live, _Filter.soon => soon, _Filter.fresh => fresh };
    final confirmable = visible.where((s) => s.needsConfirm).toList();
    final confirmed = visible.where((s) => !s.needsConfirm).toList();
    var cascadeIndex = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (!backfillDone) _AnalyzingBanner(),
        _Hero(summary: summary, play: play),
        const SizedBox(height: 16),
        if (live.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Усі · ${live.length}', selected: filter == _Filter.all, onTap: () => onFilter(_Filter.all)),
                const SizedBox(width: 8),
                if (soon.isNotEmpty)
                  _FilterChip(
                      label: 'Скоро списання · ${soon.length}',
                      kind: _ChipKind.soon,
                      selected: filter == _Filter.soon,
                      onTap: () => onFilter(_Filter.soon)),
                if (soon.isNotEmpty) const SizedBox(width: 8),
                if (fresh.isNotEmpty)
                  _FilterChip(
                      label: 'Нові · ${fresh.length}',
                      kind: _ChipKind.fresh,
                      selected: filter == _Filter.fresh,
                      onTap: () => onFilter(_Filter.fresh)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (confirmable.isNotEmpty) ...[
          Text('Схоже на підписку — підтверди', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final s in confirmable) CascadeIn(index: cascadeIndex++, play: play, child: _ConfirmTile(sub: s)),
          const Divider(height: 32),
        ],
        if (confirmed.isNotEmpty) ...[
          Text('Твої підписки', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        for (final s in confirmed)
          CascadeIn(
            index: cascadeIndex++,
            play: play,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SubscriptionCard(sub: s, onTap: () => SubscriptionDetailSheet.show(context, s.id)),
            ),
          ),
        if (filter == _Filter.all && lapsed.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Можливо, скасовані', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Давно не списувались — не рахуємо їх у суму.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final s in lapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(opacity: 0.6, child: SubscriptionCard(sub: s, onTap: () => SubscriptionDetailSheet.show(context, s.id))),
            ),
        ],
        if (summary.items.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 60), child: EmptyView(title: 'Підписок не знайдено', subtitle: 'Якщо бекфіл ще йде — зачекай трохи.')),
      ],
    );
  }
}

/// Hero per the mockup: a violet card — label, the big white number counting up
/// (easeOutExpo, haptic at the end), the yearly line and a share pill inside.
class _Hero extends ConsumerWidget {
  const _Hero({required this.summary, required this.play});
  final SubscriptionsSummary summary;
  final bool play;

  // fixed brand violet in both themes — the mockup keeps the hero identical
  static const _violet = Color(0xFF6B5CE7);
  static const _label = Color(0xFFCFC7FF);
  static const _line = Color(0xFFE4DFFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveCount = summary.items.where((s) => !s.lapsed).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Підписки з\'їдають щомісяця',
              style: GoogleFonts.golosText(fontSize: 13, fontWeight: FontWeight.w500, color: _label)),
          const SizedBox(height: 6),
          CountUpText(
            value: summary.totalMonthlyMinor,
            format: formatMoney,
            play: play,
            haptic: true,
            style: GoogleFonts.rubik(
              fontSize: 44,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.44,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CountUpText(
                  value: summary.totalYearlyMinor,
                  format: (v) => '${formatMoney(v)} на рік · $liveCount підписок',
                  play: play,
                  delay: const Duration(milliseconds: 150),
                  style: GoogleFonts.golosText(fontSize: 14, fontWeight: FontWeight.w500, color: _line),
                ),
              ),
              PressScale(
                onTap: summary.items.isEmpty ? null : () => promptShare(context, summary),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ios_share, size: 17, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Поділитись', style: GoogleFonts.golosText(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChipKind { neutral, soon, fresh }

/// Filter chips per the mockup: the active one is ink with white text; the semantic
/// ones keep their tint when idle (amber for "скоро", violet for "нові").
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.kind = _ChipKind.neutral});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final (bg, fg) = selected
        ? (ink, theme.colorScheme.surface)
        : switch (kind) {
            _ChipKind.soon => (const Color(0xFFFFEFC9), const Color(0xFF8A5A00)),
            _ChipKind.fresh => (const Color(0xFFE7E2FF), const Color(0xFF4A3DB8)),
            _ChipKind.neutral => (theme.colorScheme.surfaceContainerLow, theme.colorScheme.onSurfaceVariant),
          };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Motion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: GoogleFonts.golosText(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
      ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(child: SubscriptionCard(sub: sub, flat: true, onTap: () => SubscriptionDetailSheet.show(context, sub.id))),
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
