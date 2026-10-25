import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_budgets_repository.dart';
import 'limits_admin_state.dart';

final limitsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<LimitsAdminNotifier, LimitsAdminState>((ref) {
  return LimitsAdminNotifier(ref.watch(localBudgetsRepositoryProvider));
});

/// Límites desde la base local (consumo calculado en el celular); alta, edición, renovación
/// y baja por la outbox.
class LimitsAdminNotifier extends StateNotifier<LimitsAdminState> {
  final Future<LocalBudgetsRepository> _repository;

  LimitsAdminNotifier(this._repository) : super(LimitsAdminState.initial());

  /// [silencioso]: recarga tras una sincronización, sin mostrar "cargando".
  Future<void> cargarLimites({bool silencioso = false}) async {
    if (!silencioso) state = state.copyWith(status: LimitsAdminStatus.loading, clearError: true);
    try {
      final limits = await (await _repository).list();
      if (!mounted) return;
      state = state.copyWith(status: LimitsAdminStatus.loaded, limits: limits);
    } catch (e) {
      debugPrint('[PRESUPUESTOS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: LimitsAdminStatus.error, error: e);
    }
  }

  /// Ejecuta una acción local y recarga. Devuelve el error (para mostrarlo) o null.
  Future<Object?> run(Future<Object?> Function(LocalBudgetsRepository repo) action) async {
    try {
      await action(await _repository);
      await cargarLimites();
      return null;
    } catch (e) {
      debugPrint('[PRESUPUESTOS] No se guardó: $e');
      return e;
    }
  }

  void setFiltroEstado(String filtro) => state = state.copyWith(filtroEstado: filtro);
}
