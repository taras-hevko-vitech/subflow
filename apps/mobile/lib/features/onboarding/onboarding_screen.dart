import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart';
import 'onboarding_controller.dart';
import 'pages/accounts_page.dart';
import 'pages/connect_page.dart';
import 'pages/progress_page.dart';
import 'pages/security_page.dart';
import 'pages/value_page.dart';

/// Linear connect wizard (subF-14): value → security → token → accounts → progress.
/// A PageView (not routes) so the connection state threads through pages without params.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 5;

  void _goTo(int page) {
    Analytics.onboardingStep(page + 1);
    _controller.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _page > 0 && _page < 4
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _goTo(_page - 1))
            : null,
        title: _StepDots(current: _page, count: _pageCount),
        centerTitle: true,
      ),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (p) => setState(() => _page = p),
        children: [
          ValuePage(onNext: _next),
          SecurityPage(onNext: _next),
          ConnectPage(onConnected: _onConnected),
          AccountsPage(onNext: _next, connectionId: state.connectionId),
          if (state.connectionId != null)
            ProgressPage(connectionId: state.connectionId!, onDone: _finish)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.count});
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
