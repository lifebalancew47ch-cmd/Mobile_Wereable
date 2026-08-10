import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/core/security/token_service.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../domain/usecases/logout_use_case.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_api_service.dart';
import 'login_state.dart';

// Dependencias de Datos (Clean Architecture)
final authApiServiceProvider = Provider((ref) {
  final dio = ref.watch(apiClientProvider);
  final tokenService = ref.watch(tokenServiceProvider);
  return AuthApiService(dio, tokenService);
});

final authRepositoryProvider = Provider((ref) {
  final api = ref.watch(authApiServiceProvider);
  return AuthRepositoryImpl(api);
});

final loginUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

final logoutUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repo);
});

// Notifier para manejar el estado del Login
class LoginNotifier extends StateNotifier<LoginState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;

  // A-04 (fix 07/08/2026): throttling client-side contra fuerza bruta.
  // Tras 5 intentos fallidos consecutivos, el formulario se bloquea
  // 5 minutos. El backend también debe aplicar rate limiting server-side;
  // este mecanismo es una capa de defensa adicional en el cliente.
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  LoginNotifier(this._loginUseCase, this._logoutUseCase) : super(LoginState());

  Future<void> login(String email, String password) async {
    // Verificar si el formulario está bloqueado por throttling.
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final remaining = _lockedUntil!.difference(DateTime.now()).inSeconds;
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage:
            'Demasiados intentos fallidos. Espera $remaining segundos.',
      );
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: "Por favor, completa todos los campos",
      );
      return;
    }

    state = state.copyWith(status: LoginStatus.loading);

    try {
      final user = await _loginUseCase.execute(email, password);
      // Éxito: resetear contadores de throttling.
      _failedAttempts = 0;
      _lockedUntil = null;
      state = state.copyWith(status: LoginStatus.success, user: user);
    } catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockedUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
        state = state.copyWith(
          status: LoginStatus.error,
          errorMessage:
              'Cuenta bloqueada ${_lockoutDuration.inMinutes} min por múltiples intentos fallidos.',
        );
      } else {
        state = state.copyWith(
          status: LoginStatus.error,
          errorMessage: e.toString().replaceAll("Exception: ", ""),
        );
      }
    }
  }

  Future<void> logout() async {
    await _logoutUseCase.execute();
    _failedAttempts = 0;
    _lockedUntil = null;
    state = LoginState(status: LoginStatus.initial);
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final logoutUseCase = ref.watch(logoutUseCaseProvider);
  return LoginNotifier(loginUseCase, logoutUseCase);
});
