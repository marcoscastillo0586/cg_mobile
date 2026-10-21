import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final storageService = ref.watch(secureStorageServiceProvider);
  return AuthRemoteDataSource(dioClient, storageService);
});

class AuthRemoteDataSource {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRemoteDataSource(this._dioClient, this._storageService);

  Future<UserModel> login(String usuario, String password) async {
    final response = await _dioClient.post(
      ApiEndpoints.login,
      data: {
        'usuario': usuario,
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['token'] as String?;
      if (token != null) {
        await _storageService.saveToken(token);
      }

      final userData = response['usuario'] as Map<String, dynamic>? ?? response;
      final user = UserModel.fromJson(userData);
      await _storageService.saveUserJson(jsonEncode(user.toJson()));
      return user;
    }

    throw Exception('Formato de respuesta inválido en el login');
  }

  /// Verificación Offline-First del estado de autenticación
  Future<UserModel?> checkAuthStatus() async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    // 1. Cargar datos del usuario local guardado de inmediato
    UserModel? localUser;
    final savedUserJson = await _storageService.getUserJson();
    if (savedUserJson != null && savedUserJson.isNotEmpty) {
      try {
        localUser = UserModel.fromJson(jsonDecode(savedUserJson) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[AUTH-OFFLINE] Error al decodificar usuario local: $e');
      }
    }

    // 2. Intentar verificación con el servidor en segundo plano
    try {
      final response = await _dioClient.get(ApiEndpoints.checkAuth);
      if (response is Map<String, dynamic>) {
        final user = UserModel.fromJson(response);
        await _storageService.saveUserJson(jsonEncode(user.toJson()));
        return user;
      }
    } on AuthException catch (e) {
      debugPrint('[AUTH-OFFLINE] Token rechazado por servidor (401): ${e.message}');
      await _storageService.clearAll();
      return null;
    } catch (e) {
      debugPrint('[AUTH-OFFLINE] Sin conexión con servidor ($e). Manteniendo sesión local activa.');
    }

    // Retorna el usuario local o un usuario fallback si hay token
    return localUser ??
        const UserModel(
          idUsuario: 1,
          nombreUsuario: 'Usuario Offline',
          email: 'offline@gastos.com',
          rol: 'Usuario',
        );
  }

  Future<void> logout() async {
    try {
      await _dioClient.post(ApiEndpoints.logout);
    } catch (_) {
    } finally {
      await _storageService.clearAll();
    }
  }
}
