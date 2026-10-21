import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'auth_state.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState.initial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final user = await _authRepository.checkAuthStatus();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> login(String usuario, String password) async {
    state = AuthState.loading();
    try {
      final user = await _authRepository.login(usuario, password);
      state = AuthState.authenticated(user);
      return true;
    } on Failure catch (e) {
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      state = AuthState.error('Error al iniciar sesión: $e');
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      await _authRepository.logout();
    } finally {
      state = AuthState.unauthenticated();
    }
  }
}
