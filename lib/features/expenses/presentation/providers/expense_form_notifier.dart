import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/sync/pull_service.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../data/tickets_repository.dart';
import '../../domain/entities/qr_ticket.dart';
import '../../../../core/database/local_database.dart';
import '../../../movements/data/local_movement_writer.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../domain/entities/ticket_parse_result.dart';
import 'expense_form_state.dart';

final expenseFormNotifierProvider =
    StateNotifierProvider.autoDispose<ExpenseFormNotifier, ExpenseFormState>((ref) {
  return ExpenseFormNotifier(
    ref.watch(localCatalogProvider),
    ref.watch(localMovementWriterProvider),
    tickets: () => ref.read(ticketsRepositoryProvider),
    saveServerMovement: (m) async {
      final db = await ref.read(localDatabaseProvider);
      await db.transaction((txn) => PullService(db, ref.read(dioClientProvider)).upsertMovement(txn, m));
    },
  );
});

/// Formulario de egreso: lee cuentas y categorías de la base local y guarda en SQLite + outbox
/// (funciona sin conexión). El envío al servidor lo hace la sincronización.
class ExpenseFormNotifier extends StateNotifier<ExpenseFormState> {
  final Future<LocalCatalog> _catalog;
  final Future<LocalMovementWriter> _writer;

  /// Solo para tickets QR (se crea al usarse: requiere el cliente HTTP).
  final TicketsRepository Function()? _tickets;

  /// Guarda en el celular un comprobante recibido del servidor (el del ticket QR recién confirmado).
  final Future<void> Function(Map<String, dynamic> movement)? _saveServerMovement;

  /// Id estable de la confirmación del ticket QR: un reintento no duplica el egreso.
  String? _ticketClientSyncId;

  /// Resultado del último ticket QR confirmado: ya estaba registrado (no se creó otro).
  bool ticketAlreadyRegistered = false;

  /// Por qué no se pudo traer al celular el ticket ya registrado en el servidor (null si se trajo).
  Object? ticketLocalCopyError;

  late final Future<void> _loaded;

  /// Alta rechazada que este formulario corrige (se reemplaza al guardar).
  int? _replacingSeq;

  ExpenseFormNotifier(this._catalog, this._writer,
      {TicketsRepository Function()? tickets, Future<void> Function(Map<String, dynamic> movement)? saveServerMovement})
      : _tickets = tickets,
        _saveServerMovement = saveServerMovement,
        super(ExpenseFormState.initial()) {
    _loaded = inicializar();
  }

  /// Precarga un egreso rechazado para corregirlo.
  Future<void> prefill(CorrectionSource c) async {
    await _loaded;
    if (!mounted) return;
    _replacingSeq = c.seq;
    state = state.copyWith(
      selectedCuentaId: c.accountLocalId,
      fecha: c.date,
      conceptoGeneral: c.concept,
      renglones: [
        for (final l in c.lines)
          RenglonGasto.nuevo(defaultCategoriaId: l.categoryLocalId).copyWith(concepto: l.concept, montoCents: l.amountCents),
      ],
    );
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

  /// Tras traer lo del servidor al abrir: actualiza cuentas (saldos) y categorías sin tocar lo cargado.
  Future<void> recargarCatalogo() async {
    await _loaded;
    try {
      final catalog = await _catalog;
      final cuentas = await catalog.activeAccounts();
      final categorias = await catalog.expenseCategories();
      if (mounted) state = state.copyWith(cuentas: cuentas, categorias: categorias);
    } catch (e) {
      debugPrint('[EGRESO] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(error: e);
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
    final qr = parseResult.qr;
    // Categoría sugerida por el servidor (id del servidor) → id local, si está disponible para egresos.
    int? local(int? serverId) => serverId == null ? null : state.categorias.where((c) => c.serverId == serverId).map((c) => c.localId).firstOrNull;
    final renglonesNuevos = [
      for (final (i, item) in parseResult.items.indexed)
        RenglonGasto.nuevo(defaultCategoriaId: (qr == null ? null : local(qr.items[i].suggestedCategoryServerId)) ?? ticketCat).copyWith(
          concepto: item.nombre,
          montoCents: item.precioCents,
          plu: qr?.items[i].plu,
          unitPriceCents: qr?.items[i].unitPriceCents,
        ),
    ];
    // Mismo QR → mismo id: el servidor no registra dos veces el mismo ticket (devuelve el existente).
    _ticketClientSyncId = qr == null ? null : (qr.sourceUrl.isEmpty ? LocalDatabase.newId() : LocalDatabase.idFor(qr.sourceUrl));

    state = state.copyWith(
      status: ExpenseFormStatus.ready,
      ticketParseResult: parseResult,
      renglones: renglonesNuevos.isNotEmpty ? renglonesNuevos : [RenglonGasto.nuevo(defaultCategoriaId: ticketCat)],
      fecha: qr?.isoDate == null ? null : DateTime.tryParse(qr!.isoDate!),
      conceptoGeneral: qr?.generalConcept,
    );
  }

  void limpiarItemsTicket() {
    _ticketClientSyncId = null;
    state = state.copyWith(
      clearTicket: true,
      renglones: [RenglonGasto.nuevo(defaultCategoriaId: _defaultCategoria(state.categorias))],
    );
  }

  /// Guarda en el celular (SQLite + outbox). Devuelve false y deja el error en el estado si
  /// una regla no se cumple; nunca informa éxito sin haber escrito.
  Future<bool> guardarEgreso() async {
    if (state.ticketParseResult?.qr != null) return _confirmarTicketQr(state.ticketParseResult!.qr!);
    final cuenta = state.selectedCuentaId;
    if (cuenta == null) {
      state = state.copyWith(error: ValidationFailure.t((l) => l.selectSourceAccount, 'VALIDATION_ERROR'));
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
              throw ValidationFailure.t((l) => l.selectCategoryLineI(i + 1), 'VALIDATION_ERROR')
            else
              // Renglón sin concepto: usa el concepto general (como antes).
              ExpenseLine(concept: r.concepto.trim().isEmpty ? general : r.concepto, categoryLocalId: r.categoriaId!, amountCents: r.montoCents),
        ],
      ), replacingSeq: _replacingSeq);
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.success);
      return true;
    } catch (e) {
      debugPrint('[EGRESO] No se guardó: $e');
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.ready, error: e);
      return false;
    }
  }

  /// Ticket QR: se registra en el servidor con `POST /tickets/confirm` (solo con conexión),
  /// con PLU, precio unitario y la auditoría del ticket. El comprobante llega al celular en el
  /// próximo pull. Sin conexión falla y el formulario queda como estaba para reintentar.
  Future<bool> _confirmarTicketQr(QrTicket qr) async {
    final cuenta = state.cuentaSeleccionada;
    if (cuenta == null) {
      state = state.copyWith(error: ValidationFailure.t((l) => l.selectSourceAccount, 'VALIDATION_ERROR'));
      return false;
    }
    final tickets = _tickets;
    if (tickets == null) {
      state = state.copyWith(error: ValidationFailure.t((l) => l.qrReceiptsCannotConfirmedHere, 'NOT_AVAILABLE'));
      return false;
    }
    state = state.copyWith(status: ExpenseFormStatus.submitting, clearError: true);
    try {
      if (cuenta.serverId == null) {
        throw ValidationFailure.t((l) => l.accountNotServerYetSync, 'VALIDATION_ERROR');
      }
      final general = state.conceptoGeneral.trim();
      if (general.isEmpty) throw ValidationFailure.t((l) => l.fillConceptField, 'VALIDATION_ERROR');
      final items = <QrTicketConfirmItem>[];
      for (final (i, r) in state.renglones.indexed) {
        final cat = state.categorias.where((c) => c.localId == r.categoriaId).firstOrNull;
        if (cat == null) throw ValidationFailure.t((l) => l.selectCategoryLineI(i + 1), 'VALIDATION_ERROR');
        if (cat.serverId == null) {
          throw ValidationFailure.t((l) => l.categoryNameNotServerYet(cat.name), 'VALIDATION_ERROR');
        }
        if (r.montoCents <= 0) throw ValidationFailure.t((l) => l.lineIMustHaveAmount(i + 1), 'VALIDATION_ERROR');
        items.add(QrTicketConfirmItem(
          concept: r.concepto.trim().isEmpty ? general : r.concepto.trim(),
          categoryServerId: cat.serverId!,
          amountCents: r.montoCents,
          plu: r.plu,
          unitPriceCents: r.unitPriceCents,
        ));
      }
      final f = state.fecha;
      final clientSyncId = _ticketClientSyncId ??= LocalDatabase.newId();
      final confirmed = await tickets().confirm(QrTicketConfirmation(
        accountServerId: cuenta.serverId!,
        date: '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}',
        generalConcept: general,
        items: items,
        ticket: qr,
        clientSyncId: clientSyncId,
      ));
      ticketAlreadyRegistered = confirmed.duplicate;
      ticketLocalCopyError = null;
      // Ya está en el servidor: se trae al celular ahora (sin esperar al próximo pull, que por su
      // margen de 2 s todavía no lo incluye). Si falla, el egreso igual quedó registrado.
      final save = _saveServerMovement;
      if (save != null) {
        try {
          final m = await tickets().movement(confirmed.headerId);
          await save({...m, 'clientId': clientSyncId, 'version': m['version'] ?? 1});
        } catch (e) {
          debugPrint('[TICKET] Registrado en el servidor pero no se trajo al celular: $e');
          ticketLocalCopyError = e;
        }
      }
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.success);
      return true;
    } catch (e) {
      debugPrint('[TICKET] No se confirmó: $e');
      if (mounted) state = state.copyWith(status: ExpenseFormStatus.ready, error: e);
      return false;
    }
  }
}
