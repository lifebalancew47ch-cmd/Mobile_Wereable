import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/register_use_case.dart';
import 'login_provider.dart';

enum RegisterStatus { initial, loading, success, error }

class RegisterState {
  final RegisterStatus status;
  final String? errorMessage;

  RegisterState({
    this.status = RegisterStatus.initial,
    this.errorMessage,
  });

  RegisterState copyWith({
    RegisterStatus? status,
    String? errorMessage,
  }) {
    return RegisterState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final registerUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repo);
});

class RegisterNotifier extends StateNotifier<RegisterState> {
  final RegisterUseCase _registerUseCase;

  RegisterNotifier(this._registerUseCase) : super(RegisterState());

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
  }) async {
    if (email.isEmpty || username.isEmpty || password.isEmpty || 
        firstName.isEmpty || lastName.isEmpty) {
      state = state.copyWith(
        status: RegisterStatus.error,
        errorMessage: "Por favor, completa todos los campos obligatorios",
      );
      return false;
    }

    if (password != confirmPassword) {
      state = state.copyWith(
        status: RegisterStatus.error,
        errorMessage: "Las contraseñas no coinciden",
      );
      return false;
    }

    state = state.copyWith(status: RegisterStatus.loading);

    try {
      await _registerUseCase.execute(
        email: email,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
        firstName: firstName,
        lastName: lastName,
      );
      state = state.copyWith(status: RegisterStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RegisterStatus.error,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
      return false;
    }
  }
}

final registerProvider = StateNotifierProvider<RegisterNotifier, RegisterState>((ref) {
  final useCase = ref.watch(registerUseCaseProvider);
  return RegisterNotifier(useCase);
});
