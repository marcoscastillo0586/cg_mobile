import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/accounts_repository.dart';
import 'accounts_admin_state.dart';

final accountsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<AccountsAdminNotifier, AccountsAdminState>((ref) {
  return AccountsAdminNotifier(ref.watch(accountsRepositoryProvider));
});

/// Lista de cuentas. Solo lectura en esta etapa: alta, edición, activar/desactivar y
/// baja se habilitan con la cola de sincronización (etapa 8).
class AccountsAdminNotifier extends StateNotifier<AccountsAdminState> {
  final AccountsRepository _repository;

  AccountsAdminNotifier(this._repository) : super(AccountsAdminState.initial());

  Future<void> cargarCuentas() async {
    state = state.copyWith(status: AccountsAdminStatus.loading, clearError: true);
    try {
      final cuentas = await _repository.getAccounts();
      if (!mounted) return;
      state = state.copyWith(status: AccountsAdminStatus.loaded, cuentas: cuentas);
    } catch (e) {
      debugPrint('[CUENTAS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: AccountsAdminStatus.error, error: e);
    }
  }

  void toggleFiltroSoloActivas() => state = state.copyWith(mostrarSoloActivas: !state.mostrarSoloActivas);
}
