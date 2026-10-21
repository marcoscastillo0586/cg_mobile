import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource);
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<UserEntity> login(String usuario, String password) async {
    try {
      return await _remoteDataSource.login(usuario, password);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.statusCode);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.statusCode);
    } catch (e) {
      throw ServerFailure('Error inesperado al iniciar sesión: $e');
    }
  }

  @override
  Future<UserEntity?> checkAuthStatus() async {
    try {
      return await _remoteDataSource.checkAuthStatus();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
  }
}
