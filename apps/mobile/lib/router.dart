import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'features/auth/check_email_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/magic_link_screen.dart';
import 'features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthStateListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final signedIn = auth is SignedIn;
      final onAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/check-email';
      // /auth handles the magic-link deep link in both states
      if (state.matchedLocation == '/auth') return null;
      if (auth is AuthUnknown) return null; // restoring session — splash keeps showing
      if (!signedIn && !onAuthRoute) return '/login';
      if (signedIn && onAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/check-email', builder: (context, state) => CheckEmailScreen(email: state.extra as String?)),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      // magic-link entry: https://subflow.app/auth?token=... (or subflow://auth?token=...)
      GoRoute(
        path: '/auth',
        builder: (context, state) => MagicLinkScreen(token: state.uri.queryParameters['token']),
      ),
    ],
  );
});
