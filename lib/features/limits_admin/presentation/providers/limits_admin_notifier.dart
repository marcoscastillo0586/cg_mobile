import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../../dashboard/presentation/providers/novedades_notifier.dart';
import '../../data/repositories/limits_admin_repository_impl.dart';
import '../../domain/repositories/limits_admin_repository.dart';
import 'limits_admin_state.dart';

final limitsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<LimitsAdminNotifier, LimitsAdminState>((ref) {
  final repository = ref.watch(limitsAdminRepositoryProvider);
  return LimitsAdminNotifier(repository, ref);
});

class LimitsAdminNotifier extends StateNotifier<LimitsAdminState> {
  final LimitsAdminRepository _repository;
  final Ref _ref;

  LimitsAdminNotifier(this._repository, this._ref)
      : super(LimitsAdminState.initial());

  Future<void> cargarLimites() async {
    state = state.copyWith(status: LimitsAdminStatus.loading, clearMessages: true);

    try {
      final res = await _repository.getLimits();
      state = state.copyWith(
        status: LimitsAdminStatus.loaded,
        limits: res,
      );
    } on Failure catch (e) {
      state = state.copyWith(
        status: LimitsAdminStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: LimitsAdminStatus.error,
        errorMessage: 'Error al consultar presupuestos: $e',
      );
    }
  }

  void setFiltroEstado(String estado) {
    state = state.copyWith(filtroEstado: estado);
  }

  Future<bool> crearLimite({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      await _repository.createLimit(
        desde: desde,
        hasta: hasta,
        montoLimite: montoLimite,
        categoriasIds: categoriasIds,
        lugaresIds: lugaresIds,
      );

      final actualizadas = await _repository.getLimits();

      state = state.copyWith(
        isSaving: false,
        limits: actualizadas,
        successMessage: 'Límite creado exitosamente',
      );

      await _ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
      unawaited(_ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No se pudo crear el límite: $e',
      );
      return false;
    }
  }

  Future<bool> editarLimite({
    required int idLimiteGasto,
    required double montoLimite,
    DateTime? desde,
    DateTime? hasta,
    List<int>? categoriasIds,
    List<int>? lugaresIds,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final ok = await _repository.updateLimit(
        idLimiteGasto: idLimiteGasto,
        montoLimite: montoLimite,
        desde: desde,
        hasta: hasta,
        categoriasIds: categoriasIds,
        lugaresIds: lugaresIds,
      );

      if (ok) {
        final actualizadas = await _repository.getLimits();
        state = state.copyWith(
          isSaving: false,
          limits: actualizadas,
          successMessage: 'Límite actualizado correctamente',
        );

        await _ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
        unawaited(_ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
        return true;
      } else {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'No se pudo actualizar el límite',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al actualizar: $e',
      );
      return false;
    }
  }

  Future<bool> renovarLimite(int idLimiteGasto) async {
    state = state.copyWith(isRenewing: true, clearMessages: true);

    try {
      final ok = await _repository.renewLimit(idLimiteGasto: idLimiteGasto);
      if (ok) {
        final actualizadas = await _repository.getLimits();
        state = state.copyWith(
          isRenewing: false,
          limits: actualizadas,
          successMessage: 'Límite renovado por un nuevo mes calendario',
        );

        await _ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
        unawaited(_ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
        return true;
      } else {
        state = state.copyWith(
          isRenewing: false,
          errorMessage: 'No se pudo renovar el límite',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(isRenewing: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isRenewing: false,
        errorMessage: 'Error al renovar límite: $e',
      );
      return false;
    }
  }

  Future<bool> eliminarLimite(int idLimiteGasto) async {
    state = state.copyWith(isDeleting: true, clearMessages: true);

    try {
      final ok = await _repository.deleteLimit(idLimiteGasto: idLimiteGasto);
      if (ok) {
        final actualizadas = state.limits
            .where((l) => l.idLimiteGasto != idLimiteGasto)
            .toList();

        state = state.copyWith(
          isDeleting: false,
          limits: actualizadas,
          successMessage: 'Límite eliminado con éxito',
        );

        await _ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
        unawaited(_ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
        return true;
      } else {
        state = state.copyWith(
          isDeleting: false,
          errorMessage: 'No se pudo eliminar el límite',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(isDeleting: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Error al eliminar límite: $e',
      );
      return false;
    }
  }
}
