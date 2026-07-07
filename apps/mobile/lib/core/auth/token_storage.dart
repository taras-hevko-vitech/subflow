import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT pair lives ONLY in the platform keychain/keystore.
class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _kAccess = 'subflow.accessToken';
  static const _kRefresh = 'subflow.refreshToken';

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<void> savePair({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
