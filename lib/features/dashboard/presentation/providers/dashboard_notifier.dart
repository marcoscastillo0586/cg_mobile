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
      // Se conserva la selección del usuario, limitada a las cuentas que siguen apareciendo.
      final seleccion = state.cuentasSeleccionadasIds?.intersection(ids) ?? ids;
      state = state.copyWith(status: DashboardStatus.loaded, balances: balances, cuentasSeleccionadasIds: seleccion);
    } catch (e) {
      debugPrint('[DASHBOARD] No se pudieron cargar los saldos: $e');
      if (!mounted) return;
      state = state.copyWith(status: DashboardStatus.error, error: e);
    }
  }

  void toggleVisibilidadMontos() => state = state.copyWith(ocultarMontos: !state.ocultarMontos);

  void toggleCuentaSeleccionada(int id) {
    final actuales = Set<int>.from(state.idsSeleccionados);
    if (!actuales.remove(id)) actuales.add(id);
    state = state.copyWith(cuentasSeleccionadasIds: actuales);
  }
}
