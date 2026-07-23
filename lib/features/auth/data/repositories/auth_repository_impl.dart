import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;
  AuthRepositoryImpl(this.dataSource);

  @override
  Future<User> login(String email, String password) => dataSource.login(email, password);

  @override
  Future<User> register(String email, String password, String name) => dataSource.register(email, password, name);

  @override
  Future<void> forgotPassword(String email) => dataSource.forgotPassword(email);

  @override
  Future<void> logout() => dataSource.logout();

  @override
  Future<User?> getCurrentUser() async {
    // Para el mock, siempre empezamos sin sesión
    return null;
  }
}
