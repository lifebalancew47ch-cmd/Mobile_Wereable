import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/certificate_pinning.dart';
import '../security/token_service.dart';

/// Reintenta peticiones fallidas por indisponibilidad transitoria del backend
/// (500/502/503/429) o errores de red con backoff exponencial, SIN degradar
/// nunca el canal a HTTP o sin TLS. Los fallos de TLS nunca se reintentan.
class RetryWithBackoffInterceptor extends Interceptor {
  RetryWithBackoffInterceptor(
    this._dio, {
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
  });

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;

  int _attempts = 0;

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
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_attempts < maxAttempts && _isRetryable(err)) {
      _attempts++;
      Future<void>.delayed(baseDelay * _attempts, () async {
        try {
          final response = await _dio.fetch<dynamic>(err.requestOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      });
      return;
    }
    _attempts = 0;
    handler.next(err);
  }
}

Dio _buildDio(Ref ref, String baseUrl) {
  return buildSecureDio(baseUrl, authService: ref.watch(tokenServiceProvider));
}

/// Construye un cliente Dio con la seguridad del proyecto (pinning estricto,
/// reintentos con backoff, auth Bearer) sin depender de Riverpod. Reutilizable
/// desde aislados de segundo plano donde no existe [Ref].
Dio buildSecureDio(String baseUrl, {TokenService? authService}) {
  final tokenService = authService ?? TokenService(const FlutterSecureStorage());

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
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
