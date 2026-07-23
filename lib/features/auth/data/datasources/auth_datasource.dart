import '../../domain/entities/user.dart';

abstract class AuthDataSource {
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String name);
  Future<void> forgotPassword(String email);
  Future<void> logout();
}

class MockAuthDataSource implements AuthDataSource {
  @override
  Future<User> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    if (email == 'error@test.com') throw Exception('Credenciales inválidas');
    return User(id: '1', email: email, name: 'Usuario Prueba');
  }

  @override
  Future<User> register(String email, String password, String name) async {
    await Future.delayed(const Duration(seconds: 2));
    return User(id: '2', email: email, name: name);
  }

  @override
  Future<void> forgotPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
