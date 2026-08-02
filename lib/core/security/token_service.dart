import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(const FlutterSecureStorage());
});

/// Señal global que notifica cambios de sesión (login/logout/expiración).
/// El router la usa como `refreshListenable` para re-evaluar las redirecciones
/// y expulsar al usuario a /login cuando su sesión deja de ser válida.
final ValueNotifier<int> sessionChangeNotifier = ValueNotifier<int>(0);

void _notifySessionChange() {
  sessionChangeNotifier.value++;
}

class TokenService {
  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const String _userCacheKey = 'cached_user_profile';

  TokenService(this._storage);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    _notifySessionChange();
  }

  Future<void> invalidateSession() async {
    await clearTokens();
  }

  Future<void> saveCachedUser(String userJsonStr) async {
    await _storage.write(key: _userCacheKey, value: userJsonStr);
  }

  Future<String?> getCachedUser() async {
    return await _storage.read(key: _userCacheKey);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userCacheKey);
    _notifySessionChange();
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final expiry = _extractExpiry(token);
    if (expiry == null) return true;
    return DateTime.now().isBefore(expiry);
  }

  /// Decodifica el claim `exp` de un JWT (payload en base64url).
  /// Devuelve null si el token no es JWT o no trae exp (se considera válido).
  DateTime? _extractExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return null;
      final exp = payload['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());
      }
      return null;
    } catch (_) {
      // Tokens no JWT (incompletos) no se rechazan para no romper proveedores
      // que firmen sin payload estándar; la validación fuerte la hace el backend.
      return null;
    }
  }
}
