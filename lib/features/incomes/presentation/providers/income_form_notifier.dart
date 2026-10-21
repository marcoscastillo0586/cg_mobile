import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/income_repository.dart';
import 'package:gastos_mobile/features/incomes/data/repositories/income_repository_impl.dart';
import 'income_form_state.dart';

final incomeFormNotifierProvider =
    StateNotifierProvider.autoDispose<IncomeFormNotifier, IncomeFormState>((ref) {
  final repository = ref.watch(incomeRepositoryProvider);
  return IncomeFormNotifier(repository);
});

class IncomeFormNotifier extends StateNotifier<IncomeFormState> {
  final IncomeRepository _repository;

  IncomeFormNotifier(this._repository) : super(IncomeFormState.initial()) {
    cargarLugares();
  }

  Future<void> cargarLugares() async {
    state = state.copyWith(status: IncomeFormStatus.loading);
    try {
      final lugares = await _repository.getLugares();
      // Punto 8.2: Inicia sin ninguna cuenta seleccionada (null)
      int? defaultLugar;

      state = state.copyWith(
        status: IncomeFormStatus.ready,
        lugares: lugares,
        selectedLugarId: defaultLugar,
      );
    } catch (_) {
      state = state.copyWith(status: IncomeFormStatus.ready);
    }
  }

  void setLugar(int idLugar) {
    state = state.copyWith(selectedLugarId: idLugar);
  }

  void setMonto(double monto) {
    state = state.copyWith(monto: monto);
  }

  void setConcepto(String concepto) {
    state = state.copyWith(concepto: concepto);
  }

  void setFecha(DateTime fecha) {
    state = state.copyWith(fecha: fecha);
  }

  Future<bool> guardarIngreso() async {
    if (state.selectedLugarId == null) {
      state = state.copyWith(errorMessage: 'Selecciona una cuenta de destino');
      return false;
    }

    if (state.monto <= 0) {
      state = state.copyWith(errorMessage: 'Ingresa un monto mayor a cero');
      return false;
    }

    final fechaStr = DateFormat('yyyy-MM-dd').format(state.fecha);
    final concepto = state.concepto.trim().isEmpty ? 'Ingreso de dinero' : state.concepto.trim();

    state = state.copyWith(status: IncomeFormStatus.submitting, errorMessage: null);

    try {
      final ok = await _repository.createIncome(
        idLugar: state.selectedLugarId!,
        monto: state.monto,
        concepto: concepto,
        fecha: fechaStr,
      );

      if (ok) {
        state = state.copyWith(status: IncomeFormStatus.success);
        return true;
      } else {
        state = state.copyWith(
          status: IncomeFormStatus.ready,
          errorMessage: 'No se pudo guardar el ingreso',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: IncomeFormStatus.ready,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: IncomeFormStatus.ready,
        errorMessage: 'Error inesperado: $e',
      );
      return false;
    }
  }
}
