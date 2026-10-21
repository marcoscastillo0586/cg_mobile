import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String usuario, String password);
  Future<UserEntity?> checkAuthStatus();
  Future<void> logout();
}
