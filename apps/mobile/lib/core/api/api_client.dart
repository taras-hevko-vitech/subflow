import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Dio with the auth contract wired in: attach the access token, and on a 401 try one
/// refresh (rotation-aware: the server revokes the whole session set on refresh reuse,
/// so a failed refresh means sign-out, never a retry loop).
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 10)));

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final access = await storage.accessToken;
        if (access != null && !options.path.startsWith('/auth/')) {
          options.headers['authorization'] = 'Bearer $access';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (response?.statusCode != 401 || alreadyRetried || error.requestOptions.path.startsWith('/auth/')) {
          return handler.next(error);
        }
        final refresh = await storage.refreshToken;
        if (refresh == null) return handler.next(error);
        try {
          final fresh = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
              .post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
          final data = fresh.data;
          if (data == null) return handler.next(error);
          await storage.savePair(access: data['accessToken'] as String, refresh: data['refreshToken'] as String);
          final retry = error.requestOptions..extra['retried'] = true;
          retry.headers['authorization'] = 'Bearer ${data['accessToken']}';
          handler.resolve(await dio.fetch(retry));
        } catch (_) {
          await storage.clear(); // refresh rejected → session is gone
          handler.next(error);
        }
      },
    ),
  );
  return dio;
});
