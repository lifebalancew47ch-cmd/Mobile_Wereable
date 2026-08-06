import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/certificate_pinning.dart';
import '../security/token_service.dart';
import '../security/secure_storage.dart';

/// Reintenta peticiones fallidas por indisponibilidad transitoria del backend
/// (500/502/503/429) o errores de red con backoff exponencial + jitter, SIN
/// degradar nunca el canal a HTTP o sin TLS. Los fallos de TLS nunca se
/// reintentan.
///
/// A-06 (audit de seguridad): el contador de reintentos vivía como estado de
/// instancia (`_attempts`), compartido por TODAS las peticiones concurrentes
/// de este Dio -- con varias peticiones en paralelo (el dashboard las lanza
/// así), tres fallos simultáneos consumían los 3 intentos entre las tres, y
/// el primer éxito reseteaba el contador a 0 dejando que las demás
/// reintentaran sin límite real. Además el retry corría en un
/// `Future.delayed` sin `await`: `onError` retornaba de inmediato y, con
/// `maxAttempts` agotado, `handler.next(err)` podía llamarse dos veces
/// (una desde el `Future` en vuelo, otra desde una llamada posterior) ->
/// `StateError`. Ahora el contador vive en `err.requestOptions.extra`, que
/// es por petición, y el reintento se espera de verdad.
class RetryWithBackoffInterceptor extends Interceptor {
  RetryWithBackoffInterceptor(
    this._dio, {
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
  });

  static const _retryCountKey = '_retry_count';

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;
  final Random _random = Random();

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.cancel ||
        err.type == DioExceptionType.badCertificate) {
      return false;
    }
    final status = err.response?.statusCode;
    if (status != null) {
      return status == 500 || status == 502 || status == 503 || status == 429;
    }
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final count = (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;
    if (count >= maxAttempts || !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    err.requestOptions.extra[_retryCountKey] = count + 1;

    // Backoff exponencial real (antes era lineal: baseDelay * intento) con
    // jitter para que clientes que fallaron a la vez no reintenten
    // sincronizados y amplifiquen la caída del backend (efecto manada).
    final exponentialDelay = baseDelay * (1 << count);
    final jitter = Duration(milliseconds: _random.nextInt(200));
    await Future<void>.delayed(exponentialDelay + jitter);

    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

Dio _buildDio(Ref ref, String baseUrl) {
  return buildSecureDio(baseUrl, authService: ref.watch(tokenServiceProvider));
}

/// Construye un cliente Dio con la seguridad del proyecto (pinning estricto,
/// reintentos con backoff, auth Bearer) sin depender de Riverpod. Reutilizable
/// desde aislados de segundo plano donde no existe [Ref].
Dio buildSecureDio(String baseUrl, {TokenService? authService}) {
  final tokenService = authService ?? TokenService(secureStorage);

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 45),
    receiveTimeout: const Duration(seconds: 45),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // SSL/TLS Pinning estricto a nivel de adapter (certificado hoja):
  // verifica la huella SHA-256 contra PINNED_CERT_SHA256. Sin pins
  // configurados -> fail-closed (la conexión TLS se bloquea).
  dio.httpClientAdapter = IOHttpClientAdapter(
    validateCertificate: CertificatePinning.validateCertificate,
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Authorization header if token exists
        final token = await tokenService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Token inválido o expirado: se limpia la sesión y el router
        // (refreshListenable) redirige automáticamente a /login.
        if (e.response?.statusCode == 401) {
          await tokenService.clearTokens();
        }
        return handler.next(e);
      },
    ),
  );

  // Reintentos de resiliencia transitoria (500/503): nunca reintenta
  // errores de certificado ni degrada el canal a cleartext.
  dio.interceptors.add(RetryWithBackoffInterceptor(dio));

  return dio;
}

final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'API_URL',
    'https://lifebalance-auth-service.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final dashboardApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'DASHBOARD_API_URL',
    'https://lifebalance-dashboard-service.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final notificationsApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'NOTIFICATIONS_API_URL',
    'https://lifebalance-notifications-api.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final ingestionApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'INGESTION_API_URL',
    'https://ingestion-service-fouo.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final gamificationApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'GAMIFICATION_API_URL',
    'https://gamification-service-9o3z.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final sedentaryApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'SEDENTARY_API_URL',
    'https://sedentary-engine-service.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final medicalApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'MEDICAL_API_URL',
    'https://medical-service-hb0v.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

final mlApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = _envBaseUrl(
    'ML_API_URL',
    'https://ml-prediction-service-0sqa.onrender.com/api/v1',
  );
  return _buildDio(ref, baseUrl);
});

/// Lee una variable de entorno de forma segura. Si dotenv no está cargado
/// (p. ej. en tests unitarios), devuelve el fallback en lugar de lanzar
/// [NotInitializedError].
String _envBaseUrl(String key, String fallback) {
  if (!dotenv.isInitialized) return fallback;
  return dotenv.env[key] ?? fallback;
}
