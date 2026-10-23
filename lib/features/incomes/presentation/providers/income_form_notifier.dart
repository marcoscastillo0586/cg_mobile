import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../movements/data/local_movement_writer.dart';
import 'income_form_state.dart';

final incomeFormNotifierProvider =
    StateNotifierProvider.autoDispose<IncomeFormNotifier, IncomeFormState>((ref) {
  return IncomeFormNotifier(ref.watch(localCatalogProvider), ref.watch(localMovementWriterProvider));
});

/// Concepto que usaba la app cuando el campo queda vacío (el servidor exige uno).
const conceptoIngresoPorDefecto = 'Ingreso de dinero';

/// Formulario de ingreso: cuentas de la base local; guarda en SQLite + outbox (sin conexión).
class IncomeFormNotifier extends StateNotifier<IncomeFormState> {
  final Future<LocalCatalog> _catalog;
  final Future<LocalMovementWriter> _writer;

  late final Future<void> _loaded;
  int? _replacingSeq;

  IncomeFormNotifier(this._catalog, this._writer) : super(IncomeFormState.initial()) {
    _loaded = cargarCuentas();
  }

  /// Precarga un ingreso rechazado para corregirlo.
  Future<void> prefill(CorrectionSource c) async {
    await _loaded;
    if (!mounted) return;
    _replacingSeq = c.seq;
    state = state.copyWith(selectedCuentaId: c.accountLocalId, montoCents: c.amountCents, concepto: c.concept, fecha: c.date);
  }

  Future<void> cargarCuentas() async {
    state = state.copyWith(status: IncomeFormStatus.loading, clearError: true);
    try {
      final cuentas = await (await _catalog).activeAccounts();
      // Punto 8.2: inicia sin ninguna cuenta seleccionada.
      if (mounted) state = state.copyWith(status: IncomeFormStatus.ready, cuentas: cuentas);
    } catch (e) {
      debugPrint('[INGRESO] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(status: IncomeFormStatus.error, error: e);
    }
  }

  void setCuenta(int localId) => state = state.copyWith(selectedCuentaId: localId, clearError: true);

  void setMonto(int cents) => state = state.copyWith(montoCents: cents);

  void setConcepto(String concepto) => state = state.copyWith(concepto: concepto);

  void setFecha(DateTime fecha) => state = state.copyWith(fecha: fecha);

  Future<bool> guardarIngreso() async {
    final cuenta = state.selectedCuentaId;
    if (cuenta == null) {
      state = state.copyWith(error: const ValidationFailure('Selecciona una cuenta de destino', null, 'VALIDATION_ERROR'));
      return false;
    }
    final concepto = state.concepto.trim().isEmpty ? conceptoIngresoPorDefecto : state.concepto;
    state = state.copyWith(status: IncomeFormStatus.submitting, clearError: true);
    try {
      await (await _writer).createIncome(
        IncomeDraft(accountLocalId: cuenta, date: state.fecha, concept: concepto, amountCents: state.montoCents),
        replacingSeq: _replacingSeq,
      );
      if (mounted) state = state.copyWith(status: IncomeFormStatus.success);
      return true;
    } catch (e) {
      debugPrint('[INGRESO] No se guardó: $e');
      if (mounted) state = state.copyWith(status: IncomeFormStatus.ready, error: e);
      return false;
    }
  }
}
