import '../../../../core/auth/session_manager.dart';
import '../entities/user_entity.dart';

/// Resultado de recuperar la sesión al abrir la app.
class RestoredSession {
  final UserEntity user;

  /// true si no se pudo hablar con el servidor y se usa el último usuario confirmado.
  final bool offline;

  /// Error de red o del servidor que impidió confirmar la sesión (si [offline]).
  final Object? connectionError;

  const RestoredSession(this.user, {this.offline = false, this.connectionError});
}

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);

  /// null si no hay sesión guardada. Lanza [SessionExpiredException] si el servidor la rechazó.
  Future<RestoredSession?> restoreSession();

  /// Revoca en el servidor, borra la base local y los datos de sesión. Conserva los ajustes.
  Future<LogoutOutcome> logout();

  /// Emite cuando la sesión expira durante el uso.
  Stream<Object> get onSessionExpired;
}
