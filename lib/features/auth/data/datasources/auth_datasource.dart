import '../../domain/entities/user.dart';

abstract class AuthDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String name);
  Future<void> forgotPassword(String email);
  Future<void> logout();
}
