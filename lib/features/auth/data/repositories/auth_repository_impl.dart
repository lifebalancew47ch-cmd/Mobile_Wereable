import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_service.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthApiService apiService;

  AuthRepositoryImpl(this.apiService);

  @override
  Future<UserModel> login(String email, String password) {
    return apiService.loginMock(email, password);
  }
}
