import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/secure_database_service.dart';
import '../utils/app_log.dart';
import 'encryption_service.dart';
import 'secure_storage.dart';
import 'session_cleanup.dart';

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(secureStorage);
});

/// Señal global que notifica cambios de sesión (login/logout/expiración).
/// El router la usa como `refreshListenable` para re-evaluar las redirecciones
/// y expulsar al usuario a /login cuando su sesión deja de ser válida.
final ValueNotifier<int> sessionChangeNotifier = ValueNotifier<int>(0);

void _notifySessionChange() {
  sessionChangeNotifier.value++;
}

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userCacheKey = 'user_cache';

  final FlutterSecureStorage _storage;

  TokenService(this._storage);

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> saveUserData(String userDataJson) async {
    await _storage.write(key: _userCacheKey, value: userDataJson);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: _userCacheKey);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// SessionWiper: borra tokens, purga registros de salud en la BD SQLCipher,
  /// regenera la clave de encriptación AES y limpia datos biométricos/wearable en SharedPreferences.
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userCacheKey);
    await _storage.delete(key: 'biometric_gender');
    await _storage.delete(key: 'biometric_height_cm');
    await _storage.delete(key: 'biometric_weight_kg');
    await _storage.delete(key: 'biometric_age');

    try {
      await SecureDatabaseService.instance.purgeAllData();
      await EncryptionService.clearEncryptionKey();
    } catch (e) {
      AppLog.d('[SessionWiper] Error purgando base de datos cifrada o clave AES: $e');
    }

    // Las claves no-credenciales que otros servicios escriben en
    // almacenamiento plano (biométricos locales, último JSON del wearable,
    // estado del FogEngine nativo) se limpian aquí, aisladas en
    // `session_cleanup.dart`: token_service.dart jamás escribe tokens fuera
    // del secure storage.
    await clearSensitiveSharedPreferences();

    _notifySessionChange();
  }

  /// Margen de tolerancia para evitar 401 justo en el límite de expiración
  /// por desfase de reloj entre dispositivo y servidor.
  static const Duration _clockSkewMargin = Duration(seconds: 30);

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final expiry = _extractExpiry(token);
    // M-01 (audit de seguridad): antes un token sin `exp` decodificable
    // (opaco, truncado, corrupto, o con firma inválida -- `_extractExpiry`
    // devuelve null ante cualquier error) se consideraba válido para
    // siempre y pasaba el guard del router. Ahora se rechaza: si el token
    // no se puede validar localmente, que falle en la próxima llamada a la
    // API (que sí lo valida) en vez de dejar pasar a la app.
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry.subtract(_clockSkewMargin));
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
