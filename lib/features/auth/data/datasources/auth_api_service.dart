import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:lifebalance/core/security/token_service.dart';
import '../../domain/entities/user_model.dart';
import '../../domain/entities/auth_tokens.dart';

class AuthApiService {
  final Dio _dio;
  final TokenService _tokenService;

  AuthApiService(this._dio, this._tokenService);

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final tokens = AuthTokens.fromJson(data);
        await _tokenService.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        
        // El login podría retornar el usuario o solo el token, 
        // Si no devuelve el usuario, llamamos a /profile para obtenerlo.
        if (data['userProfile'] != null) {
          return UserModel.fromJson(data['userProfile']);
        } else {
          return await getProfile();
        }
      } else {
        throw Exception(response.data['message'] ?? 'Error en el inicio de sesión');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Error de servidor';
        throw Exception(message);
      }
      throw Exception('Error de conexión');
    }
  }

  Future<UserModel> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
        'confirmPassword': confirmPassword,
        'firstName': firstName,
        'lastName': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      });

      if (response.data['success'] == true) {
        // Asumimos que no loguea automáticamente tras registro
        // Si el backend devuelve los datos del user, lo retornamos
        return UserModel.fromJson(response.data['data'] ?? {});
      } else {
        throw Exception(response.data['message'] ?? 'Error en el registro');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Error al registrarse';
        throw Exception(message);
      }
      throw Exception('Error de conexión');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Error al procesar solicitud');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Error de servidor');
    }
  }

  Future<void> logout() async {
    try {
      // Opcionalmente avisar al backend
      await _dio.post('/auth/logout', data: {});
    } catch (e) {
      // Ignorar si falla, igual borraremos tokens localmente
    } finally {
      await _tokenService.clearTokens();
    }
  }

  Future<UserModel> getProfile() async {
    try {
      final response = await _dio.get('/Profile/me');
      if (response.data['success'] == true) {
        return UserModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'No se pudo obtener el perfil');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Error al obtener perfil');
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }
}
