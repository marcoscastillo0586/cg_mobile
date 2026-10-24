import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/balances_repository.dart';
import 'dashboard_state.dart';

final dashboardNotifierProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(balancesRepositoryProvider));
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  final BalancesRepository _repository;

  DashboardNotifier(this._repository) : super(DashboardState.initial()) {
    cargarDashboard();
  }

  /// Carga los saldos. [hasta] (`yyyy-MM-dd`) filtra a una fecha de corte; null = hoy.
  Future<void> cargarDashboard({String? hasta}) async {
    state = state.copyWith(
      status: DashboardStatus.loading,
      fechaFiltro: hasta,
      clearFecha: hasta == null,
      clearError: true,
    );
    try {
      final balances = await _repository.getBalances(until: hasta);
      if (!mounted) return;
      final ids = balances.accounts.map((c) => c.id).toSet();
      // Se conservan las cuentas que el usuario desmarcó; las nuevas entran marcadas.
      state = state.copyWith(
          status: DashboardStatus.loaded, balances: balances, cuentasExcluidasIds: state.cuentasExcluidasIds.intersection(ids));
    } catch (e) {
      debugPrint('[DASHBOARD] No se pudieron cargar los saldos: $e');
      if (!mounted) return;
      state = state.copyWith(status: DashboardStatus.error, error: e);
    }
  }

  void toggleVisibilidadMontos() => state = state.copyWith(ocultarMontos: !state.ocultarMontos);

  void toggleCuentaSeleccionada(int id) {
    final excluidas = Set<int>.from(state.cuentasExcluidasIds);
    if (!excluidas.remove(id)) excluidas.add(id);
    state = state.copyWith(cuentasExcluidasIds: excluidas);
  }
}
