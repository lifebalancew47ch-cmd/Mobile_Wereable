import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_api_service.dart';
import 'login_state.dart';

// Dependencias de Datos (Clean Architecture)
final authApiServiceProvider = Provider((ref) => AuthApiService());

final authRepositoryProvider = Provider((ref) {
  final api = ref.watch(authApiServiceProvider);
  return AuthRepositoryImpl(api);
});

final loginUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

// Notifier para manejar el estado del Login
class LoginNotifier extends StateNotifier<LoginState> {
  final LoginUseCase _loginUseCase;

  LoginNotifier(this._loginUseCase) : super(LoginState());

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
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  final useCase = ref.watch(loginUseCaseProvider);
  return LoginNotifier(useCase);
});
