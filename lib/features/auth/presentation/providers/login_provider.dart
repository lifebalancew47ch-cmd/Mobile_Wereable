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

  LoginNotifier(this._loginUseCase, this._logoutUseCase) : super(LoginState());

  Future<void> login(String email, String password) async {
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
      state = state.copyWith(status: LoginStatus.success, user: user);
    } catch (e) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }

  Future<void> logout() async {
    await _logoutUseCase.execute();
    state = LoginState(status: LoginStatus.initial);
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final logoutUseCase = ref.watch(logoutUseCaseProvider);
  return LoginNotifier(loginUseCase, logoutUseCase);
});
