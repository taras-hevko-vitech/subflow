import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'features/auth/check_email_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/magic_link_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

/// Debug-only initial route override for UI screenshots without driving the whole auth flow:
///   flutter run --dart-define=DEV_ROUTE=/onboarding
const _devRoute = String.fromEnvironment('DEV_ROUTE');

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      // magic-link entry: https://subflow.app/auth?token=... (or subflow://auth?token=...)
      GoRoute(path: '/auth', builder: (context, state) => MagicLinkScreen(token: state.uri.queryParameters['token'])),
    ],
  );
});
