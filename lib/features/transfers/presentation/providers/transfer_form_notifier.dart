import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/transfer_repository.dart';
import 'package:gastos_mobile/features/transfers/data/repositories/transfer_repository_impl.dart';
import 'transfer_form_state.dart';

final transferFormNotifierProvider =
    StateNotifierProvider.autoDispose<TransferFormNotifier, TransferFormState>((ref) {
  final repository = ref.watch(transferRepositoryProvider);
  return TransferFormNotifier(repository);
});

class TransferFormNotifier extends StateNotifier<TransferFormState> {
  final TransferRepository _repository;

  TransferFormNotifier(this._repository) : super(TransferFormState.initial()) {
    cargarLugares();
  }

  Future<void> cargarLugares() async {
    state = state.copyWith(status: TransferFormStatus.loading);
    try {
      final lugares = await _repository.getLugares();

      final origen = lugares.isNotEmpty ? lugares.first.idLugar : null;
      final destino = lugares.length > 1 ? lugares[1].idLugar : null;

      state = state.copyWith(
        status: TransferFormStatus.ready,
        lugares: lugares,
        selectedOrigenId: origen,
        selectedDestinoId: destino,
      );
    } catch (_) {
      state = state.copyWith(status: TransferFormStatus.ready);
    }
  }

  void setOrigen(int idOrigen) {
    if (idOrigen == state.selectedDestinoId) {
      final otro = state.lugares.firstWhere(
        (l) => l.idLugar != idOrigen,
        orElse: () => state.lugares.first,
      );
      state = state.copyWith(selectedOrigenId: idOrigen, selectedDestinoId: otro.idLugar);
    } else {
      state = state.copyWith(selectedOrigenId: idOrigen);
    }
  }

  void setDestino(int idDestino) {
    if (idDestino == state.selectedOrigenId) {
      final otro = state.lugares.firstWhere(
        (l) => l.idLugar != idDestino,
        orElse: () => state.lugares.first,
      );
      state = state.copyWith(selectedDestinoId: idDestino, selectedOrigenId: otro.idLugar);
    } else {
      state = state.copyWith(selectedDestinoId: idDestino);
    }
  }

  void intercambiarCuentas() {
    final prevOrigen = state.selectedOrigenId;
    final prevDestino = state.selectedDestinoId;
    state = state.copyWith(
      selectedOrigenId: prevDestino,
      selectedDestinoId: prevOrigen,
    );
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

  Future<bool> realizarTransferencia() async {
    if (state.selectedOrigenId == null || state.selectedDestinoId == null) {
      state = state.copyWith(errorMessage: 'Selecciona cuenta de origen y destino');
      return false;
    }

    if (state.selectedOrigenId == state.selectedDestinoId) {
      state = state.copyWith(errorMessage: 'La cuenta origen y destino deben ser distintas');
      return false;
    }

    if (state.monto <= 0) {
      state = state.copyWith(errorMessage: 'Ingresa un monto mayor a cero');
      return false;
    }

    final fechaStr = DateFormat('yyyy-MM-dd').format(state.fecha);
    final concepto = state.concepto.trim().isEmpty ? 'Transferencia entre cuentas' : state.concepto.trim();

    state = state.copyWith(status: TransferFormStatus.submitting, errorMessage: null);

    try {
      final ok = await _repository.createTransfer(
        idOrigen: state.selectedOrigenId!,
        idDestino: state.selectedDestinoId!,
        monto: state.monto,
        concepto: concepto,
        fecha: fechaStr,
      );

      if (ok) {
        state = state.copyWith(status: TransferFormStatus.success);
        return true;
      } else {
        state = state.copyWith(
          status: TransferFormStatus.ready,
          errorMessage: 'No se pudo realizar la transferencia',
        );
        return false;
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: TransferFormStatus.ready,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: TransferFormStatus.ready,
        errorMessage: 'Error inesperado: $e',
      );
      return false;
    }
  }
}
