import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Aviso no bloqueante para mostrar en el login (p. ej. sesión expirada o logout sin red).
enum AuthNotice { sessionExpired, logoutNotRevoked }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;

  /// Error del último intento (se traduce en la UI con ErrorMessages).
  final Object? error;

  /// Autenticado con el último usuario confirmado, sin poder hablar con el servidor.
  final bool offline;

  final AuthNotice? notice;

  /// Detalle del [notice] (p. ej. el error de red al revocar en el servidor).
  final Object? noticeError;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.offline = false,
    this.notice,
    this.noticeError,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserEntity user, {bool offline = false, Object? connectionError}) =>
      AuthState(status: AuthStatus.authenticated, user: user, offline: offline, error: connectionError);
  factory AuthState.unauthenticated({AuthNotice? notice, Object? noticeError}) =>
      AuthState(status: AuthStatus.unauthenticated, notice: notice, noticeError: noticeError);
  factory AuthState.error(Object error) => AuthState(status: AuthStatus.error, error: error);

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  @override
  List<Object?> get props => [status, user, error, offline, notice, noticeError];
}
