import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'features/auth/check_email_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/magic_link_screen.dart';
import 'features/home/home_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/feedback_screen.dart';
import 'features/profile/privacy_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/security_screen.dart';

/// Debug-only initial route override for UI screenshots without driving the whole auth flow:
///   flutter run --dart-define=DEV_ROUTE=/onboarding
const _devRoute = String.fromEnvironment('DEV_ROUTE');

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _devRoute.isNotEmpty ? _devRoute : '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      if (_devRoute.isNotEmpty) return null; // never redirect during a screenshot session
      final auth = ref.read(authControllerProvider);
      final signedIn = auth is SignedIn;
      final loc = state.matchedLocation;
      final onAuthRoute = loc == '/login' || loc == '/check-email';
      if (loc == '/auth') return null; // magic-link deep link works in both states
      if (auth is AuthUnknown) return null; // restoring session — splash keeps showing
      if (!signedIn && !onAuthRoute) return '/login';
      if (signedIn && onAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/check-email', builder: (context, state) => CheckEmailScreen(email: state.extra as String?)),
      // main app frame per the mockups: Головна · Сповіщення · Профіль
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())]),
        ],
      ),
      // full-screen flows above the shell
      GoRoute(path: '/onboarding', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/security', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const SecurityScreen()),
      GoRoute(path: '/feedback', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const FeedbackScreen()),
      GoRoute(path: '/privacy', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const PrivacyScreen()),
      // magic-link entry: https://subflow.app/auth?token=... (or subflow://auth?token=...)
      GoRoute(path: '/auth', builder: (context, state) => MagicLinkScreen(token: state.uri.queryParameters['token'])),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.6)))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Головна'),
            NavigationDestination(
                icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Сповіщення'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профіль'),
          ],
        ),
      ),
    );
  }
}
