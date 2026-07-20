import '../../domain/entities/user_model.dart';

class AuthApiService {
  Future<UserModel> loginMock(String email, String password) async {
    // Simula una llamada a API en la futura capa Cloud (Sección 2)
    await Future.delayed(const Duration(seconds: 2));

    if (email == "admin@lifebalance.com" && password == "admin123") {
      return UserModel(
        id: "unique_id_123",
        email: email,
        name: "Admin LifeBalance",
      );
    } else {
      throw Exception("Credenciales incorrectas. Intenta con admin@lifebalance.com / admin123");
    }
  }
}
