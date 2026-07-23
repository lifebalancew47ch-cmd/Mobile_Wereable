import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/token_service.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final tokenService = ref.watch(tokenServiceProvider);
  final baseUrl = dotenv.env['API_URL'] ?? 'https://auth-profile.onrender.com/api/v1';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

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

  return dio;
});
