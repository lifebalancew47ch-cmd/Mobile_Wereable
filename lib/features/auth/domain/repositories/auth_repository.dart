import '../entities/user_model.dart';

abstract class IAuthRepository {
  Future<UserModel> login(String email, String password);
}
