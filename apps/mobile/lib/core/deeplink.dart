import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

/// Routes incoming links (universal https://subflow.app/... once the domain is live,
/// and the subflow:// scheme which works today) into go_router.
class DeepLinkHandler {
  DeepLinkHandler(this._router);

  final GoRouter _router;
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (initial != null) _handle(initial);
    _sub = appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    // https://subflow.app/auth?token=... → /auth?token=...   subflow://auth?token=... → same
    final path = uri.host == 'auth' ? '/auth' : uri.path;
    if (path == '/auth') {
      _router.go(Uri(path: '/auth', queryParameters: uri.queryParameters).toString());
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final handler = DeepLinkHandler(ref.watch(routerProvider));
  ref.onDispose(handler.dispose);
  return handler;
});
