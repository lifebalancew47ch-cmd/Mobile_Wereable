import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);
  Future<User> execute(String email, String password) => repository.login(email, password);
}

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);
  Future<User> execute(String email, String password, String name) => repository.register(email, password, name);
}

class ForgotPasswordUseCase {
  final AuthRepository repository;
  ForgotPasswordUseCase(this.repository);
  Future<void> execute(String email) => repository.forgotPassword(email);
}

class LogoutUseCase {
  final AuthRepository repository;
  LogoutUseCase(this.repository);
  Future<void> execute() => repository.logout();
}
