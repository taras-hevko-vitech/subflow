import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/auth/token_storage.dart';
import 'core/config.dart';
import 'core/deeplink.dart';
import 'router.dart';
import 'theme.dart';

/// Debug-only: pre-seed an access token so the authed screens can be screenshotted
/// without driving the (dialog-gated) deep-link flow. Never runs in release.
///   flutter run --dart-define=DEV_TOKEN=<jwt> --dart-define=DEV_ROUTE=/home
const _devToken = String.fromEnvironment('DEV_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode && _devToken.isNotEmpty) {
    await TokenStorage().savePair(access: _devToken, refresh: 'dev-refresh');
  }
  runApp(const ProviderScope(child: SubflowApp()));
}

class SubflowApp extends ConsumerStatefulWidget {
  const SubflowApp({super.key});

  @override
  ConsumerState<SubflowApp> createState() => _SubflowAppState();
}

class _SubflowAppState extends ConsumerState<SubflowApp> {
  @override
  void initState() {
    super.initState();
    if (AppConfig.sentryDsn.isNotEmpty) {
      // no-op without a DSN, so local dev never needs a Sentry project
      SentryFlutter.init((o) => o.dsn = AppConfig.sentryDsn);
    }
    ref.read(deepLinkHandlerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Subflow',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}
