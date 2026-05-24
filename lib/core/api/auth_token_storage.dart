import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacena/recupera el JWT de forma segura.
class AuthTokenStorage {
  AuthTokenStorage._();
  static final AuthTokenStorage instance = AuthTokenStorage._();

  static const _kToken = 'jwt_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _cachedToken;

  String? get token => _cachedToken;

  Future<void> load() async {
    _cachedToken = await _storage.read(key: _kToken);
  }

  Future<void> save(String token) async {
    _cachedToken = token;
    await _storage.write(key: _kToken, value: token);
  }

  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _kToken);
  }
}
