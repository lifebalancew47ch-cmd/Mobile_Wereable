import '../entities/user_model.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<UserModel> execute(String email, String password) {
    return repository.login(email, password);
  }
}
