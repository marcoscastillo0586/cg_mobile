import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../movements/data/local_movement_writer.dart';
import 'transfer_form_state.dart';

final transferFormNotifierProvider =
    StateNotifierProvider.autoDispose<TransferFormNotifier, TransferFormState>((ref) {
  return TransferFormNotifier(ref.watch(localCatalogProvider), ref.watch(localMovementWriterProvider));
});

/// Formulario de transferencia: cuentas de la base local; guarda en SQLite + outbox (sin conexión).
class TransferFormNotifier extends StateNotifier<TransferFormState> {
  final Future<LocalCatalog> _catalog;
  final Future<LocalMovementWriter> _writer;

  late final Future<void> _loaded;
  int? _replacingSeq;

  TransferFormNotifier(this._catalog, this._writer) : super(TransferFormState.initial()) {
    _loaded = cargarCuentas();
  }

  /// Precarga una transferencia rechazada para corregirla.
  Future<void> prefill(CorrectionSource c) async {
    await _loaded;
    if (!mounted) return;
    _replacingSeq = c.seq;
    if (c.fromLocalId != null) setOrigen(c.fromLocalId!);
    if (c.toLocalId != null) setDestino(c.toLocalId!);
    state = state.copyWith(montoCents: c.amountCents, concepto: c.concept, fecha: c.date);
  }

  /// Tras traer lo del servidor al abrir: actualiza cuentas (saldos) sin tocar lo cargado.
  Future<void> recargarCuentas() async {
    await _loaded;
    try {
      final cuentas = await (await _catalog).activeAccounts();
      if (mounted) state = state.copyWith(cuentas: cuentas);
    } catch (e) {
      debugPrint('[TRANSFERENCIA] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<void> cargarCuentas() async {
    state = state.copyWith(status: TransferFormStatus.loading, clearError: true);
    try {
      final cuentas = await (await _catalog).activeAccounts();
      if (!mounted) return;
      state = state.copyWith(status: TransferFormStatus.ready, cuentas: cuentas);
      if (cuentas.isNotEmpty) setOrigen(cuentas.first.localId);
    } catch (e) {
      debugPrint('[TRANSFERENCIA] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(status: TransferFormStatus.error, error: e);
    }
  }

  /// Cambia el origen y, si el destino deja de ser válido (misma cuenta u otra moneda), elige otro.
  void setOrigen(int localId) {
    state = state.copyWith(selectedOrigenId: localId, clearError: true);
    final validos = state.destinosValidos;
    if (!validos.any((c) => c.localId == state.selectedDestinoId)) {
      state = validos.isEmpty ? state.copyWith(clearDestino: true) : state.copyWith(selectedDestinoId: validos.first.localId);
    }
  }

  void setDestino(int localId) {
    if (state.destinosValidos.any((c) => c.localId == localId)) {
      state = state.copyWith(selectedDestinoId: localId, clearError: true);
    }
  }

  void intercambiarCuentas() {
    final origen = state.selectedOrigenId, destino = state.selectedDestinoId;
    if (origen == null || destino == null) return;
    state = state.copyWith(selectedOrigenId: destino, selectedDestinoId: origen);
  }

  void setMonto(int cents) => state = state.copyWith(montoCents: cents);

  void setConcepto(String concepto) => state = state.copyWith(concepto: concepto);

  void setFecha(DateTime fecha) => state = state.copyWith(fecha: fecha);

  Future<bool> realizarTransferencia() async {
    final origen = state.selectedOrigenId, destino = state.selectedDestinoId;
    if (origen == null || destino == null) {
      state = state.copyWith(error: ValidationFailure.t((l) => l.selectSourceDestinationAccounts, 'VALIDATION_ERROR'));
      return false;
    }
    state = state.copyWith(status: TransferFormStatus.submitting, clearError: true);
    try {
      await (await _writer).createTransfer(TransferDraft(
        fromLocalId: origen,
        toLocalId: destino,
        amountCents: state.montoCents,
        date: state.fecha,
        concept: state.concepto, // vacío: el del servidor ("Transferencia desde X hacia Y")
      ), replacingSeq: _replacingSeq);
      if (mounted) state = state.copyWith(status: TransferFormStatus.success);
      return true;
    } catch (e) {
      debugPrint('[TRANSFERENCIA] No se guardó: $e');
      if (mounted) state = state.copyWith(status: TransferFormStatus.ready, error: e);
      return false;
    }
  }
}
