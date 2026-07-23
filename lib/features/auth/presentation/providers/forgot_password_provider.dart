import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/forgot_password_use_case.dart';
import 'login_provider.dart';

enum ForgotPasswordStatus { initial, loading, sent, error }

class ForgotPasswordState {
  final ForgotPasswordStatus status;
  final String? errorMessage;

  ForgotPasswordState({
    this.status = ForgotPasswordStatus.initial,
    this.errorMessage,
  });

  ForgotPasswordState copyWith({
    ForgotPasswordStatus? status,
    String? errorMessage,
  }) {
    return ForgotPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final forgotPasswordUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ForgotPasswordUseCase(repo);
});

class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  final ForgotPasswordUseCase _forgotPasswordUseCase;

  ForgotPasswordNotifier(this._forgotPasswordUseCase) : super(ForgotPasswordState());

  Future<bool> sendInstructions(String email) async {
    if (email.isEmpty) {
      state = state.copyWith(
        status: ForgotPasswordStatus.error,
        errorMessage: "Por favor, ingresa tu correo electrónico",
      );
      return false;
    }

    state = state.copyWith(status: ForgotPasswordStatus.loading);

    try {
      await _forgotPasswordUseCase.execute(email);
      state = state.copyWith(status: ForgotPasswordStatus.sent);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ForgotPasswordStatus.error,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
      return false;
    }
  }
}

final forgotPasswordProvider = StateNotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>((ref) {
  final useCase = ref.watch(forgotPasswordUseCaseProvider);
  return ForgotPasswordNotifier(useCase);
});
