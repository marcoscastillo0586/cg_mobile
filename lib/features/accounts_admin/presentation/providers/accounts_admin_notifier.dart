import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/failures.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../../transfers/data/datasources/transfer_remote_data_source.dart';
import '../../data/repositories/accounts_admin_repository_impl.dart';
import '../../domain/entities/account_admin_entity.dart';
import '../../domain/repositories/accounts_admin_repository.dart';
import 'accounts_admin_state.dart';

final accountsAdminNotifierProvider =
    StateNotifierProvider.autoDispose<AccountsAdminNotifier, AccountsAdminState>((ref) {
  final repository = ref.watch(accountsAdminRepositoryProvider);
  return AccountsAdminNotifier(repository, ref);
});

class AccountsAdminNotifier extends StateNotifier<AccountsAdminState> {
  final AccountsAdminRepository _repository;
  final Ref _ref;

  AccountsAdminNotifier(this._repository, this._ref)
      : super(AccountsAdminState.initial());

  Future<void> cargarCuentas() async {
    state = state.copyWith(status: AccountsAdminStatus.loading, clearMessages: true);

    try {
      final res = await _repository.getAccounts(todos: true);
      state = state.copyWith(
        status: AccountsAdminStatus.loaded,
        cuentas: res,
      );
    } on Failure catch (e) {
      state = state.copyWith(
        status: AccountsAdminStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AccountsAdminStatus.error,
        errorMessage: 'Error al consultar cuentas: $e',
      );
    }
  }

  void toggleFiltroSoloActivas() {
    state = state.copyWith(
      mostrarSoloActivas: !state.mostrarSoloActivas,
    );
  }

  Future<bool> crearCuenta({
    required String nombre,
    required int tipoMoneda,
    String? img,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final nueva = await _repository.createAccount(
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        img: img,
      );

      final actualizadas = [nueva, ...state.cuentas];
      state = state.copyWith(
        isSaving: false,
        cuentas: actualizadas,
        successMessage: 'Cuenta "${nueva.nombre}" creada con éxito',
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al crear cuenta: $e',
      );
      return false;
    }
  }

  Future<bool> editarCuenta({
    required int idLugar,
    required String nombre,
    required int tipoMoneda,
    required bool activo,
  }) async {
    // Caso 3: Si se intenta desactivar la única cuenta existente
    if (!activo && state.cuentas.length <= 1) {
      state = state.copyWith(
        errorMessage: 'No es posible desactivar la única cuenta existente en el sistema',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final editada = await _repository.updateAccount(
        idLugar: idLugar,
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        activo: activo,
      );

      final actualizadas = state.cuentas.map((c) {
        if (c.idLugar == idLugar) {
          return c.copyWith(
            nombre: editada.nombre,
            tipoMoneda: editada.tipoMoneda,
            monedaSimbolo: editada.tipoMoneda == 2 ? 'USD' : 'ARS',
            esUsd: editada.tipoMoneda == 2,
            activo: editada.activo,
          );
        }
        return c;
      }).toList();

      state = state.copyWith(
        isSaving: false,
        cuentas: actualizadas,
        successMessage: 'Cuenta "${editada.nombre}" actualizada',
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al actualizar cuenta: $e',
      );
      return false;
    }
  }

  Future<bool> toggleEstado({
    required int idLugar,
    required bool nuevoActivo,
  }) async {
    // Caso 3: Si se intenta desactivar la única cuenta existente
    if (!nuevoActivo && state.cuentas.length <= 1) {
      state = state.copyWith(
        errorMessage: 'No es posible desactivar la única cuenta existente en el sistema',
      );
      return false;
    }

    try {
      final ok = await _repository.toggleAccountStatus(
        idLugar: idLugar,
        activo: nuevoActivo,
      );

      if (ok) {
        final actualizadas = state.cuentas.map((c) {
          if (c.idLugar == idLugar) {
            return c.copyWith(activo: nuevoActivo);
          }
          return c;
        }).toList();

        state = state.copyWith(
          cuentas: actualizadas,
          successMessage: nuevoActivo ? 'Cuenta activada' : 'Cuenta desactivada',
        );

        unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> transferirYDesactivar({
    required int idOrigen,
    required int idDestino,
    required double monto,
    required String monedaSimbolo,
  }) async {
    // Caso 3: Si es la única cuenta existente en el sistema
    if (state.cuentas.length <= 1) {
      state = state.copyWith(
        errorMessage: 'No es posible desactivar la única cuenta existente en el sistema',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearMessages: true);
    try {
      final transferDataSource = _ref.read(transferRemoteDataSourceProvider);
      final okTransfer = await transferDataSource.createTransfer(
        idOrigen: idOrigen,
        idDestino: idDestino,
        monto: monto,
        concepto: 'Transferencia por desactivación de cuenta',
        fecha: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );

      if (okTransfer) {
        await _repository.toggleAccountStatus(idLugar: idOrigen, activo: false);
        await cargarCuentas();
        unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
        state = state.copyWith(isSaving: false, successMessage: 'Fondos transferidos y cuenta desactivada');
        return true;
      }
      state = state.copyWith(isSaving: false, errorMessage: 'No se pudo realizar la transferencia de fondos');
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Error al transferir fondos: $e');
      return false;
    }
  }

  Future<bool> eliminarCuenta(int idLugar) async {
    // Caso 3: Si es la única cuenta
    if (state.cuentas.length <= 1) {
      state = state.copyWith(
        errorMessage: 'No es posible desactivar la única cuenta existente en el sistema',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final res = await _repository.deleteAccount(idLugar: idLugar);

      List<AccountAdminEntity> actualizadas;
      if (res.eliminadoFisico) {
        actualizadas = state.cuentas.where((c) => c.idLugar != idLugar).toList();
      } else {
        actualizadas = state.cuentas.map((c) {
          if (c.idLugar == idLugar) {
            return c.copyWith(activo: false);
          }
          return c;
        }).toList();
      }

      state = state.copyWith(
        isSaving: false,
        cuentas: actualizadas,
        successMessage: res.mensaje,
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al eliminar cuenta: $e',
      );
      return false;
    }
  }
}
