import '../entities/user_model.dart';
import '../repositories/auth_repository.dart';

class GetProfileUseCase {
  final AuthRepository repository;

  GetProfileUseCase(this.repository);

  Future<UserModel> execute() {
    return repository.getProfile();
  }
}
