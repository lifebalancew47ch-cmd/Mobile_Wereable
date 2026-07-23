import '../entities/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  
  Future<UserModel> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  });

  Future<void> forgotPassword(String email);
  
  Future<void> logout();
  
  Future<UserModel> getProfile();
}
