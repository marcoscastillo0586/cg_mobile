import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/budgets_repository.dart';
import 'limits_admin_state.dart';

final limitsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<LimitsAdminNotifier, LimitsAdminState>((ref) {
  return LimitsAdminNotifier(ref.watch(budgetsRepositoryProvider));
});

/// Presupuestos. Solo lectura en esta etapa: alta, edición, renovación y baja se
/// habilitan con la cola de sincronización (etapa 8).
class LimitsAdminNotifier extends StateNotifier<LimitsAdminState> {
  final BudgetsRepository _repository;

  LimitsAdminNotifier(this._repository) : super(LimitsAdminState.initial());

  Future<void> cargarLimites() async {
    state = state.copyWith(status: LimitsAdminStatus.loading, clearError: true);
    try {
      final limits = await _repository.getBudgets();
      if (!mounted) return;
      state = state.copyWith(status: LimitsAdminStatus.loaded, limits: limits);
    } catch (e) {
      debugPrint('[PRESUPUESTOS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: LimitsAdminStatus.error, error: e);
    }
  }

  void setFiltroEstado(String filtro) => state = state.copyWith(filtroEstado: filtro);
}
