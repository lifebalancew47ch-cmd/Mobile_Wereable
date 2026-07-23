import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiService apiService;
  AuthRepositoryImpl(this.apiService);

  @override
  Future<UserModel> login(String email, String password) {
    return apiService.login(email, password);
  }

  @override
  Future<UserModel> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) {
    return apiService.register(
      email: email,
      username: username,
      password: password,
      confirmPassword: confirmPassword,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<void> forgotPassword(String email) {
    return apiService.forgotPassword(email);
  }

  @override
  Future<void> logout() {
    return apiService.logout();
  }

  @override
  Future<UserModel> getProfile() {
    return apiService.getProfile();
  }
}
