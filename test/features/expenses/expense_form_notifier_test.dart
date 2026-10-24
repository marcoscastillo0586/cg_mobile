// Formulario de egreso contra SQLite REAL (ffi). No prueba la pantalla ni el celular.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/expenses/data/tickets_repository.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/qr_ticket.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/ticket_parse_result.dart';
import 'package:gastos_mobile/features/expenses/presentation/providers/expense_form_notifier.dart';
import 'package:gastos_mobile/features/expenses/presentation/providers/expense_form_state.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late ProviderContainer container;
  late ExpenseFormNotifier notifier;

  setUp(() async {
    s = await seededDb();
    container = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
    container.listen(expenseFormNotifierProvider, (_, __) {}); // evita el autoDispose
    notifier = container.read(expenseFormNotifierProvider.notifier);
    await notifier.inicializar();
  });

  tearDown(() async {
    container.dispose();
    await s.db.close();
  });

  String first() => notifier.state.renglones.first.id;

  test('carga cuentas activas y categorías de egreso de la base local; sin cuenta elegida', () {
    expect(notifier.state.status, ExpenseFormStatus.ready);
    expect(notifier.state.cuentas.map((c) => c.name), ['Banco', 'Dolares', 'Efectivo']); // sin la inactiva
    expect(notifier.state.categorias.map((c) => c.name), ['Comida', 'Super', 'Ticket']); // sin reservadas
    expect(notifier.state.selectedCuentaId, isNull);
    expect(notifier.state.renglones, hasLength(1));
  });

  test('total en centavos enteros y aviso de fondos antes de guardar', () {
    notifier.setCuenta(s.accounts['Efectivo']!);
    notifier.actualizarMonto(first(), 4000);
    notifier.agregarRenglon();
    notifier.actualizarMonto(notifier.state.renglones[1].id, 1001);
    expect(notifier.state.totalCents, 5001);
    expect(notifier.state.fondosInsuficientes, isTrue); // saldo 5000
    notifier.actualizarMonto(notifier.state.renglones[1].id, 1000);
    expect(notifier.state.fondosInsuficientes, isFalse);
  });

  test('guardar escribe en SQLite y la outbox y descuenta el saldo local', () async {
    notifier.setCuenta(s.accounts['Banco']!);
    notifier.setConceptoGeneral('Compras');
    notifier.actualizarMonto(first(), 4500);
    notifier.actualizarCategoria(first(), s.categories['Super']!);
    expect(await notifier.guardarEgreso(), isTrue);
    expect(notifier.state.status, ExpenseFormStatus.success);
    expect(await s.count('outbox', "status = 'pending'"), 1);
    expect(await s.balance('Banco'), 100000 - 4500);
    // Renglón sin concepto: toma el concepto general.
    expect(await s.count('movement_details', "concept = 'Compras' AND amount_cents = -4500"), 1);
  });

  test('sin fondos: avisa (fondosInsuficientes) pero se guarda y la cuenta queda en negativo', () async {
    notifier.setCuenta(s.accounts['Efectivo']!);
    notifier.setConceptoGeneral('x');
    notifier.actualizarMonto(first(), 5001);
    expect(notifier.state.fondosInsuficientes, isTrue);
    expect(notifier.state.isFormComplete, isTrue); // no bloquea
    expect(await notifier.guardarEgreso(), isTrue);
    expect(await s.balance('Efectivo'), -1);
    expect(await s.count('outbox', "status = 'pending'"), 1);
  });

  test('sin cuenta: error de validación, no se escribe', () async {
    notifier.actualizarMonto(first(), 100);
    expect(await notifier.guardarEgreso(), isFalse);
    expect((notifier.state.error! as Failure).code, 'VALIDATION_ERROR');
    expect(await s.count('movement_headers', 'server_id IS NULL'), 0);
  });

  test('ticket: precios a centavos y categoría DEFAULT_TICKET', () {
    notifier.aplicarResultadoTicket(const TicketParseResult(readerName: 'test', rawTexts: [], imagePaths: [], items: [
      ParsedTicketItem(nombre: 'Leche', precioCents: 123450),
      ParsedTicketItem(nombre: 'Pan', precioCents: 10),
    ]));
    expect(notifier.state.renglones.map((r) => (r.concepto, r.montoCents, r.categoriaId)), [
      ('Leche', 123450, s.categories['Ticket']),
      ('Pan', 10, s.categories['Ticket']),
    ]);
  });

  test('sugerencia sin conexión: la última categoría usada con ese concepto', () async {
    final w = await s.writer;
    await w.createExpense(ExpenseDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 1, 2), generalConcept: 'x',
        lines: [ExpenseLine(concept: 'Verduras', categoryLocalId: s.categories['Super']!, amountCents: 100)]));
    notifier.actualizarConcepto(first(), 'verduras');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(notifier.state.renglones.first.categoriaId, s.categories['Super']);
  });

  group('ticket QR (POST /tickets/confirm, solo con conexión)', () {
    late _ConfirmServer server;
    late ExpenseFormNotifier qrNotifier;
    setUp(() async {
      server = _ConfirmServer();
      final repo = TicketsRepository(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1');
      qrNotifier = ExpenseFormNotifier(s.catalog, s.writer, tickets: () => repo);
      await qrNotifier.inicializar();
    });
    tearDown(() => qrNotifier.dispose());

    // Super tiene server_id 6 en los datos sembrados.
    const qr = QrTicket(
      reader: 'coto-estructurado', sourceUrl: 'https://apps01.coto.com.ar/x', merchant: 'COTO', branch: 'SUC131', isoDate: '2026-10-02',
      totalPrintedCents: 192789, itemsTotalCents: 192789,
      items: [QrTicketItem(description: 'GALL.RELLENA', plu: '00000000015889', unitPriceCents: 296599, netCents: 192789, suggestedCategoryServerId: 6, doubtful: false)],
    );
    TicketParseResult result() => const TicketParseResult(readerName: 'coto-estructurado', rawTexts: [], imagePaths: [], totalDetectadoCents: 192789, qr: qr,
        items: [ParsedTicketItem(nombre: 'GALL.RELLENA', precioCents: 192789)]);

    test('precarga fecha, concepto y la categoría sugerida (id del servidor → local); confirma con ids del servidor', () async {
      qrNotifier.aplicarResultadoTicket(result());
      final st = qrNotifier.state;
      expect((st.conceptoGeneral, st.fecha, st.renglones.single.categoriaId), ('COTO SUC131', DateTime(2026, 10, 2), s.categories['Super']));
      qrNotifier.setCuenta(s.accounts['Banco']!);
      expect(await qrNotifier.guardarEgreso(), isTrue);
      final body = server.bodies.single;
      expect((body['accountId'], body['date'], body['generalConcept']), (1, '2026-10-02', 'COTO SUC131'));
      expect(body['items'], [
        {'concept': 'GALL.RELLENA', 'categoryId': 6, 'amount': '1927.89', 'plu': '00000000015889', 'unitPrice': '2965.99'},
      ]);
      expect(await s.count('outbox'), 0); // no pasa por la outbox: lo registra el servidor
    });

    test('sin conexión: falla, el formulario queda igual y el reintento usa el MISMO clientSyncId', () async {
      qrNotifier.aplicarResultadoTicket(result());
      qrNotifier.setCuenta(s.accounts['Banco']!);
      server.online = false;
      expect(await qrNotifier.guardarEgreso(), isFalse);
      expect(qrNotifier.state.error, isA<NetworkException>());
      expect(qrNotifier.state.renglones, hasLength(1));
      server.online = true;
      expect(await qrNotifier.guardarEgreso(), isTrue);
      expect(server.bodies.map((b) => b['clientSyncId']).toSet(), hasLength(1));
      expect(server.bodies, hasLength(2));
    });
  });
}

class _ConfirmServer implements HttpClientAdapter {
  bool online = true;
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    bodies.add(Map<String, dynamic>.from(o.data as Map));
    if (!online) throw DioException.connectionError(requestOptions: o, reason: 'sin red (simulado)');
    return ResponseBody.fromString(jsonEncode({'headerId': 99, 'ticketId': 1, 'duplicate': false}), 201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
