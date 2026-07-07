import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'token_storage.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.email);
  final String email;
}

class AuthController extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    _restore();
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    if (await _storage.accessToken == null) {
      state = const SignedOut();
      return;
    }
    try {
      final me = await _dio.get<Map<String, dynamic>>('/me');
      state = SignedIn(me.data?['email'] as String? ?? '');
    } on DioException {
      state = const SignedOut(); // token dead and refresh failed → interceptor cleared storage
    }
  }

  /// 204 no matter what — the API never reveals whether an email exists.
  Future<void> requestMagicLink(String email) async {
    await _dio.post<void>('/auth/request', data: {'email': email});
  }

  /// `token` comes from the mail's link (deep link ?token=... or a pasted URL/token).
  Future<void> verify(String token) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/verify', data: {'token': token});
    final data = res.data;
    if (data == null) throw StateError('empty verify response');
    await _storage.savePair(access: data['accessToken'] as String, refresh: data['refreshToken'] as String);
    await _restore();
  }

  Future<void> signOut() async {
    await _storage.clear();
    state = const SignedOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// go_router redirect hook: re-evaluates routes whenever auth state flips.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) => notifyListeners());
  }
}
