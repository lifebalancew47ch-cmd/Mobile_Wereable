import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/certificate_pinning.dart';
import '../security/token_service.dart';
import '../security/secure_storage.dart';

// ---------------------------------------------------------------------------
// C-01 (fix 07/08/2026): URLs de microservicios y pins TLS migrados a
// --dart-define para que no viajen como archivos de texto en el bundle del
// APK/IPA. Pasar en el comando de build:
//   flutter build apk --release \
//     --dart-define=API_URL=https://... \
//     --dart-define=PINNED_CERT_SHA256=AB:CD:...,...
//
// B-05 (fix 07/08/2026): en release, el defaultValue es '' para que un build
// sin --dart-define falle rápidamente (URL vacía → DioException) en vez de
// exponer los dominios reales en el binario. En debug el fallback sigue
// apuntando a producción para que los desarrolladores no necesiten configurar
// nada extra en su entorno local.
// ---------------------------------------------------------------------------

/// True en AOT/release, false en debug/profile.
const bool _kIsRelease = bool.fromEnvironment('dart.vm.product');

const kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: _kIsRelease ? '' : 'https://lifebalance-auth-service.onrender.com/api/v1',
);
const kDashboardApiUrl = String.fromEnvironment(
  'DASHBOARD_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://lifebalance-dashboard-service.onrender.com/api/v1',
);
const kNotificationsApiUrl = String.fromEnvironment(
  'NOTIFICATIONS_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://lifebalance-notifications-api.onrender.com/api/v1',
);
const kIngestionApiUrl = String.fromEnvironment(
  'INGESTION_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://ingestion-service-fouo.onrender.com/api/v1',
);
const kGamificationApiUrl = String.fromEnvironment(
  'GAMIFICATION_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://gamification-service-9o3z.onrender.com/api/v1',
);
const kSedentaryApiUrl = String.fromEnvironment(
  'SEDENTARY_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://sedentary-engine-service.onrender.com/api/v1',
);
const kMedicalApiUrl = String.fromEnvironment(
  'MEDICAL_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://medical-service-hb0v.onrender.com/api/v1',
);
const kMlApiUrl = String.fromEnvironment(
  'ML_API_URL',
  defaultValue: _kIsRelease ? '' : 'https://ml-prediction-service-0sqa.onrender.com/api/v1',
);

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

/// Interceptor de renovación automática de Access Token JWT (H-01, 07/08/2026).
///
/// Cuando el servidor devuelve HTTP 401, intenta renovar el token antes de
/// expulsar al usuario a /login:
///  1. Pausa la cola de peticiones en vuelo (QueuedInterceptor garantiza
///     que varias peticiones concurrentes que reciben 401 no llamen a
///     /auth/refresh múltiples veces, solo la primera lo hace y las demás
///     esperan el resultado en la cola).
///  2. Lee el Refresh Token de FlutterSecureStorage.
///  3. POST /auth/refresh → obtiene nuevo Access Token.
///  4. Si renueva: guarda ambos tokens, añade el nuevo Authorization header
///     y reintenta la petición original de forma transparente para el caller.
///  5. Si no hay Refresh Token o el refresh falla (401/403 del endpoint de
///     refresh): limpia la sesión completa → SessionWiper → router redirige
///     a /login via sessionChangeNotifier.
///
/// Se usa un Dio independiente (sin este interceptor) para la llamada al
/// endpoint de refresh, evitando bucles de recursión si /auth/refresh devuelve
/// 401 (p. ej. refresh token expirado).
class JwtRefreshInterceptor extends QueuedInterceptor {
  final TokenService _tokenService;

  // Endpoint relativo al baseUrl del auth service.
  static const _refreshPath = '/auth/refresh';

  JwtRefreshInterceptor({required TokenService tokenService})
      : _tokenService = tokenService;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    try {
      final refreshToken = await _tokenService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // Sin refresh token → sesión inválida, forzar relogin.
        await _tokenService.clearTokens();
        return handler.next(err);
      }

      // Dio limpio (sin JwtRefreshInterceptor) con pinning TLS para el refresh.
      final refreshDio = Dio(BaseOptions(
        baseUrl: kApiUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));
      refreshDio.httpClientAdapter = IOHttpClientAdapter(
        validateCertificate: CertificatePinning.validateCertificate,
      );

      final response = await refreshDio.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data;
      final newAccess = data?['accessToken'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        await _tokenService.clearTokens();
        return handler.next(err);
      }

      final newRefresh = (data?['refreshToken'] as String?) ?? refreshToken;
      await _tokenService.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      // Reintentar la petición original con el nuevo token.
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retried = await refreshDio.fetch<dynamic>(err.requestOptions);
      return handler.resolve(retried);
    } catch (_) {
      // El refresh falló (expirado, revocado, sin red): logout limpio.
      await _tokenService.clearTokens();
      return handler.next(err);
    }
  }
}

Dio _buildDio(Ref ref, String baseUrl) {
  return buildSecureDio(baseUrl, authService: ref.watch(tokenServiceProvider));
}

/// Construye un cliente Dio con la seguridad del proyecto (pinning estricto,
/// reintentos con backoff, auth Bearer, renovación de JWT) sin depender de
/// Riverpod. Reutilizable desde aislados de segundo plano donde no existe [Ref].
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

  // Añade el Bearer token en cada petición saliente.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ),
  );

  // H-01 (fix 07/08/2026): en vez de borrar el token inmediatamente al recibir
  // un 401, este interceptor intenta renovarlo con el Refresh Token antes de
  // forzar el relogin. Usa QueuedInterceptor para evitar múltiples llamadas
  // paralelas a /auth/refresh ante peticiones concurrentes.
  dio.interceptors.add(JwtRefreshInterceptor(tokenService: tokenService));

  // Reintentos de resiliencia transitoria (500/503): nunca reintenta
  // errores de certificado ni degrada el canal a cleartext.
  dio.interceptors.add(RetryWithBackoffInterceptor(dio));

  return dio;
}

final apiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kApiUrl));

final dashboardApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kDashboardApiUrl));

final notificationsApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kNotificationsApiUrl));

final ingestionApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kIngestionApiUrl));

final gamificationApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kGamificationApiUrl));

final sedentaryApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kSedentaryApiUrl));

final medicalApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kMedicalApiUrl));

final mlApiClientProvider = Provider<Dio>((ref) => _buildDio(ref, kMlApiUrl));
