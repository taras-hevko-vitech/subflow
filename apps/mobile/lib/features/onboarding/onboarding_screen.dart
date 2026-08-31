import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart';
import '../../core/motion.dart';
import 'onboarding_controller.dart';
import 'pages/accounts_page.dart';
import 'pages/connect_page.dart';
import 'pages/progress_page.dart';
import 'pages/security_page.dart';
import 'pages/value_page.dart';

/// Linear connect wizard (subF-14): value → security → token → accounts → progress.
/// Steps swap with a shared-axis X transition (design "Анімації" §1); the top progress
/// bar catches up with the new step on the same curve. Back plays the motion reversed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  bool _reverse = false;

  static const _pageCount = 5;

  void _goTo(int page) {
    Analytics.onboardingStep(page + 1);
    setState(() {
      _reverse = page < _page;
      _page = page;
    });
  }

  void _next() => _goTo(_page + 1);

  Future<void> _onConnected() async {
    // token accepted → account selection
    _next();
  }

  void _finish() {
    // partial results are already visible; back to home which now shows subscriptions
    context.go('/home');
  }

  @override
  void initState() {
    super.initState();
    Analytics.onboardingStep(1);
  }

  Widget _pageFor(int page, OnboardingState state) => switch (page) {
        0 => ValuePage(onNext: _next),
        1 => SecurityPage(onNext: _next),
        2 => ConnectPage(onConnected: _onConnected),
        3 => AccountsPage(onNext: _next, connectionId: state.connectionId),
        _ => state.connectionId != null
            ? ProgressPage(connectionId: state.connectionId!, onDone: _finish)
            : const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _page > 0 && _page < 4
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _goTo(_page - 1))
            : null,
        title: _StepBar(current: _page, count: _pageCount),
        centerTitle: true,
      ),
      body: PageTransitionSwitcher(
        duration: _reverse ? Motion.pageBack : Motion.pageForward,
        reverse: _reverse,
        transitionBuilder: (child, animation, secondaryAnimation) => SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
          child: child,
        ),
        child: KeyedSubtree(key: ValueKey(_page), child: _pageFor(_page, state)),
      ),
    );
  }
}

/// The step progress bar catches up with the new step on the emphasized curve.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.current, required this.count});
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Container(color: scheme.surfaceContainerHigh),
            AnimatedFractionallySizedBox(
              duration: Motion.pageForward,
              curve: Motion.emphasized,
              alignment: Alignment.centerLeft,
              widthFactor: (current + 1) / count,
              child: Container(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
