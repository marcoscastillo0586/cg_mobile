import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/session_manager.dart';
import '../../../../core/auth/session_providers.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(sessionManagerProvider), ref.watch(dioClientProvider));
});

/// Endpoints `/auth/*` de la API nueva.
class AuthRemoteDataSource {
  final SessionManager _session;
  final DioClient _client;

  AuthRemoteDataSource(this._session, this._client);

  Future<UserModel> login(String email, String password) async {
    final result = await _session.login(email, password);
    return UserModel.fromJson(result.user);
  }

  Future<UserModel> me() async {
    final data = await _client.get(ApiEndpoints.me);
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Respuesta inesperada de /auth/me', null, 'UNEXPECTED_RESPONSE');
    }
    return UserModel.fromJson(data);
  }

  Future<bool> hasSession() => _session.hasSession();

  Future<void> refresh() => _session.refresh();

  Future<LogoutOutcome> logout() => _session.logout();

  Stream<Object> get onExpired => _session.onExpired;
}
