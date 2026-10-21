import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription<Object> _expiredSub;

  AuthNotifier(this._authRepository) : super(AuthState.initial()) {
    // La sesión puede expirar en cualquier petición (refresh rechazado): se vuelve al login.
    _expiredSub = _authRepository.onSessionExpired.listen((_) {
      if (mounted && state.isAuthenticated) {
        state = AuthState.unauthenticated(notice: AuthNotice.sessionExpired);
      }
    });
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final restored = await _authRepository.restoreSession();
      if (!mounted) return;
      state = restored == null
          ? AuthState.unauthenticated()
          : AuthState.authenticated(
              restored.user,
              offline: restored.offline,
              connectionError: restored.connectionError,
            );
    } on SessionExpiredException {
      if (mounted) state = AuthState.unauthenticated(notice: AuthNotice.sessionExpired);
    } catch (e, st) {
      debugPrint('[AUTH] No se pudo recuperar la sesión: $e\n$st');
      if (mounted) state = AuthState.error(e);
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _authRepository.login(email, password);
      state = AuthState.authenticated(user);
      return true;
    } catch (e) {
      debugPrint('[AUTH] Login rechazado: $e');
      state = AuthState.error(e);
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      final outcome = await _authRepository.logout();
      state = AuthState.unauthenticated(
        notice: outcome.revokedOnServer ? null : AuthNotice.logoutNotRevoked,
        noticeError: outcome.serverError,
      );
    } catch (e, st) {
      // Falló el borrado local (base o almacenamiento): se informa, no se oculta.
      debugPrint('[AUTH] Error al cerrar sesión: $e\n$st');
      state = AuthState.error(e);
    }
  }

  @override
  void dispose() {
    _expiredSub.cancel();
    super.dispose();
  }
}
