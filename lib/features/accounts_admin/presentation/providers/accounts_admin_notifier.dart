import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_accounts_repository.dart';
import 'accounts_admin_state.dart';

final accountsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<AccountsAdminNotifier, AccountsAdminState>((ref) {
  return AccountsAdminNotifier(ref.watch(localAccountsRepositoryProvider));
});

/// Cuentas desde la base local; alta, edición, activar/desactivar y baja por la outbox.
class AccountsAdminNotifier extends StateNotifier<AccountsAdminState> {
  final Future<LocalAccountsRepository> _repository;

  AccountsAdminNotifier(this._repository) : super(AccountsAdminState.initial());

  Future<void> cargarCuentas() async {
    state = state.copyWith(status: AccountsAdminStatus.loading, clearError: true);
    try {
      final cuentas = await (await _repository).list();
      if (!mounted) return;
      state = state.copyWith(status: AccountsAdminStatus.loaded, cuentas: cuentas);
    } catch (e) {
      debugPrint('[CUENTAS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: AccountsAdminStatus.error, error: e);
    }
  }

  /// Ejecuta una acción local y recarga. Devuelve el error (para mostrarlo) o null.
  Future<Object?> run(Future<Object?> Function(LocalAccountsRepository repo) action) async {
    try {
      await action(await _repository);
      await cargarCuentas();
      return null;
    } catch (e) {
      debugPrint('[CUENTAS] No se guardó: $e');
      return e;
    }
  }

  void toggleFiltroSoloActivas() => state = state.copyWith(mostrarSoloActivas: !state.mostrarSoloActivas);
}
