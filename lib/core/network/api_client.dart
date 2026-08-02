import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final tokenService = ref.watch(tokenServiceProvider);

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
        // Here we could handle token refresh automatically
        // or trigger a global logout event if 401 Unauthorized is returned.
        if (e.response?.statusCode == 401) {
          // Token is invalid or expired
          await tokenService.clearTokens();
          // Note: navigation should ideally be handled via a router or auth state provider listening to this event.
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
  final baseUrl = dotenv.env['API_URL'] ?? 'https://lifebalance-auth-service.onrender.com/api/v1';
  return _buildDio(ref, baseUrl);
});

final dashboardApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['DASHBOARD_API_URL'] ??
      'https://lifebalance-dashboard-service.onrender.com/api/v1';
  return _buildDio(ref, baseUrl);
});

final notificationsApiClientProvider = Provider<Dio>((ref) {
  final baseUrl = dotenv.env['NOTIFICATIONS_API_URL'] ??
      'https://lifebalance-notifications-api.onrender.com/api/v1';
  return _buildDio(ref, baseUrl);
});
