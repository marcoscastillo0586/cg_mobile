import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../movements/data/local_movement_writer.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../domain/entities/ticket_parse_result.dart';
import 'expense_form_state.dart';

final expenseFormNotifierProvider =
    StateNotifierProvider.autoDispose<ExpenseFormNotifier, ExpenseFormState>((ref) {
  return ExpenseFormNotifier(ref.watch(localCatalogProvider), ref.watch(localMovementWriterProvider));
});

/// Formulario de egreso: lee cuentas y categorías de la base local y guarda en SQLite + outbox
/// (funciona sin conexión). El envío al servidor lo hace la sincronización.
class ExpenseFormNotifier extends StateNotifier<ExpenseFormState> {
  final Future<LocalCatalog> _catalog;
  final Future<LocalMovementWriter> _writer;

  ExpenseFormNotifier(this._catalog, this._writer) : super(ExpenseFormState.initial()) {
    inicializar();
  }

  Future<void> inicializar() async {
    state = state.copyWith(status: ExpenseFormStatus.loadingData, clearError: true);
    try {
      final catalog = await _catalog;
      final cuentas = await catalog.activeAccounts();
      final categorias = await catalog.expenseCategories();
      final conceptos = await catalog.recentExpenseConcepts();
      if (!mounted) return;
      state = state.copyWith(
        status: ExpenseFormStatus.ready,
        cuentas: cuentas,
        categorias: categorias,
        conceptos: conceptos,
        // Punto 6.5: inicia sin ninguna cuenta seleccionada.
        renglones: [RenglonGasto.nuevo(defaultCategoriaId: _defaultCategoria(categorias))],
      );
    } catch (e) {
      debugPrint('[EGRESO] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.error, error: e);
    }
  }

  static int? _defaultCategoria(List<LocalCategory> categorias) => categorias.isEmpty ? null : categorias.first.localId;

  void setCuenta(int localId) => state = state.copyWith(selectedCuentaId: localId, clearError: true);

  void setFecha(DateTime fecha) => state = state.copyWith(fecha: fecha);

  void setConceptoGeneral(String concepto) => state = state.copyWith(conceptoGeneral: concepto);

  void agregarRenglon() {
    state = state.copyWith(renglones: [
      ...state.renglones,
      RenglonGasto.nuevo(defaultCategoriaId: _defaultCategoria(state.categorias)),
    ]);
  }

  void eliminarRenglon(String id) {
    if (state.renglones.length <= 1) return;
    state = state.copyWith(renglones: state.renglones.where((r) => r.id != id).toList());
  }

  void actualizarConcepto(String id, String concepto) {
    _update(id, (r) => r.copyWith(concepto: concepto));
    _sugerirCategoria(id, concepto);
  }

  void actualizarMonto(String id, int montoCents) => _update(id, (r) => r.copyWith(montoCents: montoCents));

  void actualizarCategoria(String id, int categoriaId) => _update(id, (r) => r.copyWith(categoriaId: categoriaId));

  void _update(String id, RenglonGasto Function(RenglonGasto) change) {
    state = state.copyWith(renglones: [for (final r in state.renglones) r.id == id ? change(r) : r], clearError: true);
  }

  /// Sugerencia sin conexión: la categoría usada la última vez con ese concepto.
  Future<void> _sugerirCategoria(String renglonId, String concepto) async {
    if (concepto.trim().length < 3) return;
    try {
      final sugerida = await (await _catalog).suggestCategory(concepto);
      if (sugerida != null && mounted && state.renglones.any((r) => r.id == renglonId)) {
        actualizarCategoria(renglonId, sugerida);
      }
    } catch (e) {
      // Opcional: si falla, no se sugiere nada; el motivo queda registrado.
      debugPrint('[EGRESO] Sin sugerencia de categoría: $e');
    }
  }

  void aplicarResultadoTicket(TicketParseResult parseResult) {
    final ticketCat = state.categorias.where((c) => c.role == CategoryRoles.defaultTicket).map((c) => c.localId).firstOrNull ??
        _defaultCategoria(state.categorias);
    final renglonesNuevos = [
      for (final item in parseResult.items)
        RenglonGasto.nuevo(defaultCategoriaId: ticketCat).copyWith(
          concepto: item.nombre,
          // El lector de tickets todavía entrega double (etapa 9): se convierte una sola vez acá.
          montoCents: Money.parseInput(item.precio.toStringAsFixed(2)) ?? 0,
        ),
    ];

    final suma = parseResult.sumaRenglones;
    final totalD = parseResult.totalDetectado;
    final String feedback;
    if (totalD != null) {
      feedback = parseResult.tieneDiferenciaTotal
          ? 'Suma de renglones (\$${suma.toStringAsFixed(2)}) difiere del total detectado (\$$totalD). Verifica los montos.'
          : 'Ticket leído: Suma \$${suma.toStringAsFixed(2)} | Total \$${totalD.toStringAsFixed(2)}';
    } else {
      feedback = 'Suma de renglones: \$${suma.toStringAsFixed(2)} (No se detectó un total explícito en el ticket).';
    }

    state = state.copyWith(
      status: ExpenseFormStatus.ready,
      ticketParseResult: parseResult,
      renglones: renglonesNuevos.isNotEmpty ? renglonesNuevos : [RenglonGasto.nuevo(defaultCategoriaId: ticketCat)],
      qrFeedback: feedback,
    );
  }

  void limpiarItemsTicket() {
    state = state.copyWith(
      clearTicket: true,
      renglones: [RenglonGasto.nuevo(defaultCategoriaId: _defaultCategoria(state.categorias))],
    );
  }

  /// Guarda en el celular (SQLite + outbox). Devuelve false y deja el error en el estado si
  /// una regla no se cumple; nunca informa éxito sin haber escrito.
  Future<bool> guardarEgreso() async {
    final cuenta = state.selectedCuentaId;
    if (cuenta == null) {
      state = state.copyWith(error: const ValidationFailure('Debes seleccionar una cuenta de origen', null, 'VALIDATION_ERROR'));
      return false;
    }
    final general = state.conceptoGeneral.trim();
    state = state.copyWith(status: ExpenseFormStatus.submitting, clearError: true);
    try {
      await (await _writer).createExpense(ExpenseDraft(
        accountLocalId: cuenta,
        date: state.fecha,
        generalConcept: general,
        lines: [
          for (final (i, r) in state.renglones.indexed)
            if (r.categoriaId == null)
              throw ValidationFailure('Debes seleccionar una categoría para el Renglón #${i + 1}', null, 'VALIDATION_ERROR')
            else
              // Renglón sin concepto: usa el concepto general (como antes).
              ExpenseLine(concept: r.concepto.trim().isEmpty ? general : r.concepto, categoryLocalId: r.categoriaId!, amountCents: r.montoCents),
        ],
      ));
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.success);
      return true;
    } catch (e) {
      debugPrint('[EGRESO] No se guardó: $e');
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.ready, error: e);
      return false;
    }
  }
}
