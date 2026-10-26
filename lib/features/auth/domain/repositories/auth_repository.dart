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

  /// Revoca en el servidor y borra los tokens. Conserva los datos locales de la cuenta, sus pendientes
  /// y los ajustes del dispositivo.
  Future<LogoutOutcome> logout();

  /// Cambia el nombre para mostrar en el servidor y en la copia guardada del usuario.
  Future<UserEntity> updateDisplayName(String name);

  /// Cambia la moneda principal en el servidor y en la copia guardada del usuario.
  Future<UserEntity> updateMainCurrency(String currency);

  /// Emite cuando la sesión expira durante el uso.
  Stream<Object> get onSessionExpired;
}
