import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final IAuthRepository repository;

  ForgotPasswordUseCase(this.repository);

  Future<void> execute(String email) {
    return repository.forgotPassword(email);
  }
}
