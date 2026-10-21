import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import 'dashboard_state.dart';

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repository);
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardNotifier(this._repository) : super(DashboardState.initial()) {
    cargarDashboard();
  }

  Future<void> cargarDashboard({String? hasta}) async {
    if (state.summary == null) {
      state = state.copyWith(status: DashboardStatus.loading, fechaFiltro: hasta);
    } else {
      state = state.copyWith(fechaFiltro: hasta);
    }

    try {
      final summary = await _repository.getSaldos(hasta: hasta);
      final limites = await _repository.getLimites();

      final seleccionadas = state.cuentasSeleccionadasIds ?? summary.cuentas.map((c) => c.idLugar).toSet();

      state = state.copyWith(
        status: DashboardStatus.loaded,
        summary: summary,
        limites: limites,
        cuentasSeleccionadasIds: seleccionadas,
        errorMessage: null,
      );
    } catch (e) {
      if (state.summary != null) {
        state = state.copyWith(
          status: DashboardStatus.loaded,
          errorMessage: 'Modo sin conexión: mostrando datos guardados',
        );
      } else {
        try {
          final summary = await _repository.getSaldos(hasta: hasta);
          final limites = await _repository.getLimites();
          state = state.copyWith(
            status: DashboardStatus.loaded,
            summary: summary,
            limites: limites,
            cuentasSeleccionadasIds: summary.cuentas.map((c) => c.idLugar).toSet(),
          );
        } catch (_) {
          state = state.copyWith(
            status: DashboardStatus.loaded,
            errorMessage: 'Modo sin conexión: mostrando datos guardados',
          );
        }
      }
    }
  }

  void toggleVisibilidadMontos() {
    state = state.copyWith(ocultarMontos: !state.ocultarMontos);
  }

  void toggleCuentaSeleccionada(int idLugar) {
    final actuales = Set<int>.from(state.idsSeleccionados);
    if (actuales.contains(idLugar)) {
      actuales.remove(idLugar);
    } else {
      actuales.add(idLugar);
    }
    state = state.copyWith(cuentasSeleccionadasIds: actuales);
  }
}
