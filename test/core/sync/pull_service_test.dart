// SQLite REAL (ffi) + servidor SIMULADO con la forma de SyncPullDto. Prueba la lógica del
// pull (paginado, cursor, upsert, eliminados, verificación); la red y el servidor reales se
// prueban en el celular con tools/verify_sync.mjs.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/sync/pull_service.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Server implements HttpClientAdapter {
  final List<Object> responses; // Map = página; Exception = fallo de red
  final List<Map<String, String>> queries = [];
  _Server(this.responses);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    queries.add(o.uri.queryParameters);
    final r = responses.removeAt(0);
    if (r is Exception) throw DioException.connectionError(requestOptions: o, reason: 'sin red (simulado)');
    return ResponseBody.fromString(jsonEncode(r), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> acc(int id, String name, int balance, int count, {String currency = 'ARS'}) => {
      'id': id, 'name': name, 'currency': currency, 'active': true, 'imageUrl': null, 'iconRef': null,
      'balanceCents': balance, 'movementsCount': count, 'clientId': null, 'version': 1, 'updatedAt': '2026-10-21T10:00:00Z',
    };
Map<String, dynamic> cat(int id, String name, {String? role}) => {
      'id': id, 'name': name, 'active': true, 'role': role, 'movementsCount': 0, 'clientId': null, 'version': 1,
      'updatedAt': '2026-10-21T10:00:00Z',
    };
Map<String, dynamic> det(int id, int account, int amount, {int? category = 7}) => {
      'id': id, 'accountId': account, 'accountName': 'x', 'accountActive': true, 'currency': 'ARS', 'categoryId': category,
      'categoryName': null, 'categoryRole': null, 'concept': 'c$id', 'observation': null, 'amountCents': amount, 'plu': null,
      'unitPriceCents': null, 'imageUrl': null, 'imageNote': null,
    };
Map<String, dynamic> mov(int id, List<Map<String, dynamic>> details, {int type = 2}) => {
      'id': id, 'type': type, 'occurredAt': '2026-10-2$id 10:00:00'.substring(0, 19).padRight(19, '0'),
      'generalConcept': 'mov $id', 'accountNames': ['x'], 'amountCents': details.fold<int>(0, (a, d) => a + (d['amountCents'] as int)),
      'detailsCount': details.length, 'partialDetails': false, 'details': details, 'fromAccountId': null, 'toAccountId': null,
      'clientId': null, 'version': 1, 'updatedAt': '2026-10-21T10:00:00Z',
    };
Map<String, dynamic> page({
  List<Map<String, dynamic>> accounts = const [],
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> budgets = const [],
  List<Map<String, dynamic>> movements = const [],
  List<Map<String, dynamic>> deleted = const [],
  required String cursor,
  bool hasMore = false,
  bool full = true,
}) =>
    {
      'serverTime': '2026-10-21T10:00:00Z', 'cursor': cursor, 'hasMore': hasMore, 'full': full,
      'accounts': accounts, 'categories': categories, 'budgets': budgets, 'movements': movements, 'deleted': deleted,
    };

int firstInt(List<Map<String, Object?>> rows) => rows.first.values.first! as int;

late Directory tmp;
int _n = 0;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    tmp = Directory.systemTemp.createTempSync('cg_pull_test');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  late Database db;
  setUp(() async => db = await LocalDatabase.open(path: p.join(tmp.path, 'p${_n++}.db'), factory: databaseFactoryFfi));
  tearDown(() => db.close());

  PullService service(_Server s) {
    final client = DioClient(adapter: s)..dio.options.baseUrl = 'http://api.fake/api/v1';
    return PullService(db, client, pageSize: 2);
  }

  Future<String?> cursor() async => (await db.query('sync_state')).single['cursor'] as String?;
  Future<Map<int, int>> balances() async => {
        for (final r in await db.rawQuery(
            'SELECT a.server_id AS id, b.balance_cents AS bal FROM account_balances b JOIN accounts a ON a.local_id = b.account_local_id'))
          r['id']! as int: r['bal']! as int,
      };

  // Ventana completa en 2 páginas: 3 comprobantes, 2 cuentas.
  List<Object> fullWindow() => [
        page(
          accounts: [acc(1, 'Banco', -150050 + 200000, 2), acc(2, 'Efectivo', -3000, 1)],
          categories: [cat(7, 'Comida'), cat(1, 'Transferencia', role: 'TRANSFER')],
          movements: [mov(1, [det(10, 1, -150050)]), mov(2, [det(20, 2, -3000)])],
          cursor: 'c-page1',
          hasMore: true,
        ),
        page(movements: [mov(3, [det(30, 1, 200000, category: null)], type: 1)], cursor: 'c-end'),
      ];

  test('descarga completa paginada: aplica todo, verifica y guarda el cursor al final', () async {
    final s = _Server(fullWindow());
    final r = await service(s).pull();
    expect(r.full, isTrue);
    expect(r.pages, 2);
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect(s.queries.first.containsKey('cursor'), isFalse); // sin cursor = completa
    expect(s.queries.last['cursor'], 'c-page1');
    expect(s.queries.first['limit'], '2');
    expect(await cursor(), 'c-end');
    expect(await balances(), {1: 49950, 2: -3000});
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_headers')), 3);
    expect((await db.query('categories', where: 'server_id = 1')).single['role'], 'TRANSFER');
  });

  test('idempotente: un comprobante repetido en otra página no se duplica', () async {
    final pages = fullWindow();
    (pages[1] as Map<String, dynamic>)['movements'] = [
      mov(2, [det(20, 2, -3000)]), // repetido
      mov(3, [det(30, 1, 200000, category: null)], type: 1),
    ];
    final r = await service(_Server(pages)).pull();
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_details')), 3);
  });

  test('incremental: renglón modificado, renglón borrado y comprobante eliminado', () async {
    await service(_Server(fullWindow())).pull();
    final s = _Server([
      page(
        full: false,
        accounts: [acc(1, 'Banco', -100000, 1), acc(2, 'Efectivo', 0, 0)],
        movements: [mov(1, [det(10, 1, -100000)])],
        deleted: [{'entity': 'movement_header', 'id': 2, 'deletedAt': 'x'}, {'entity': 'movement_header', 'id': 3, 'deletedAt': 'x'}],
        cursor: 'c-2',
      ),
    ]);
    final r = await service(s).pull();
    expect(s.queries.single['cursor'], 'c-end');
    expect(r.full, isFalse);
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect(await balances(), {1: -100000, 2: 0});
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_headers')), 1);
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_details')), 1); // cascada
    expect(await cursor(), 'c-2');
  });

  test('un renglón que el servidor ya no manda en el comprobante se borra', () async {
    await service(_Server(fullWindow())).pull();
    await service(_Server([
      page(full: false, accounts: [acc(1, 'Banco', 200000, 1), acc(2, 'Efectivo', -3000, 1)],
          movements: [mov(1, [])], cursor: 'c-3'),
    ])).pull();
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_details WHERE server_id = 10')), 0);
  });

  test('descarga completa: borra lo local del servidor que ya no existe', () async {
    await service(_Server(fullWindow())).pull();
    await db.update('sync_state', {'cursor': null}, where: 'id = 1'); // fuerza otra completa
    final r = await service(_Server([
      page(accounts: [acc(1, 'Banco', -150050, 1)], categories: [cat(7, 'Comida')], movements: [mov(1, [det(10, 1, -150050)])], cursor: 'c-x'),
    ])).pull();
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect((await db.query('accounts')).map((a) => a['server_id']), [1]);
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_headers')), 1);
  });

  test('corte de red a mitad: la página 1 queda aplicada, el cursor NO avanza y el reintento completa sin duplicar', () async {
    final pages = fullWindow();
    await expectLater(service(_Server([pages[0], Exception('red')])).pull(), throwsA(isA<NetworkException>()));
    expect(await cursor(), isNull);
    final r = await service(_Server(fullWindow())).pull();
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM movement_details')), 3);
  });

  test('si no coincide con el servidor: informa la diferencia y descarta el cursor', () async {
    final pages = fullWindow();
    (pages[0] as Map<String, dynamic>)['accounts'] = [acc(1, 'Banco', 999, 2), acc(2, 'Efectivo', -3000, 1)];
    final r = await service(_Server(pages)).pull();
    expect(r.complete, isFalse);
    expect(r.mismatches.single.serverId, 1);
    expect(r.mismatches.single.localBalanceCents, 49950);
    expect(await cursor(), isNull);
  });

  test('referencia a una cuenta que no llegó: error y la página no queda a medias', () async {
    final r = service(_Server([
      page(accounts: [acc(1, 'Banco', 0, 0)], categories: [cat(7, 'Comida')], movements: [mov(1, [det(10, 99, -1)])], cursor: 'c'),
    ])).pull();
    await expectLater(r, throwsA(isA<ServerException>()));
    expect(firstInt(await db.rawQuery('SELECT COUNT(*) FROM accounts')), 0); // rollback
  });

  Future<SavedMovement> pendingExpense(int cents) async {
    final banco = firstInt(await db.rawQuery('SELECT local_id FROM accounts WHERE server_id = 1'));
    final comida = firstInt(await db.rawQuery('SELECT local_id FROM categories WHERE server_id = 7'));
    return LocalMovementWriter(db).createExpense(ExpenseDraft(
      accountLocalId: banco, date: DateTime(2026, 10, 21), generalConcept: 'offline',
      lines: [ExpenseLine(concept: 'pan', categoryLocalId: comida, amountCents: cents)],
    ));
  }

  test('lo cargado sin conexión no genera diferencia ni lo borra la descarga completa', () async {
    await service(_Server(fullWindow())).pull();
    final saved = await pendingExpense(1000);
    await db.update('sync_state', {'cursor': null}, where: 'id = 1'); // fuerza otra completa
    final r = await service(_Server(fullWindow())).pull();
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    expect((await db.query('movement_headers', where: 'local_id = ?', whereArgs: [saved.headerLocalId])), hasLength(1));
    expect(firstInt(await db.rawQuery("SELECT COUNT(*) FROM outbox WHERE status = 'pending'")), 1);
    expect((await balances())[1], 49950 - 1000); // el saldo local sigue descontado
  });

  test('el comprobante que vuelve del servidor con su clientId reemplaza los renglones locales (sin duplicar)', () async {
    await service(_Server(fullWindow())).pull();
    final saved = await pendingExpense(1000);
    final m = mov(4, [det(40, 1, -1000)])..['clientId'] = saved.clientId;
    final r = await service(_Server([
      page(full: false, accounts: [acc(1, 'Banco', 49950 - 1000, 3), acc(2, 'Efectivo', -3000, 1)], movements: [m], cursor: 'c-4'),
    ])).pull();
    expect(r.complete, isTrue, reason: r.mismatches.join('\n'));
    final h = (await db.query('movement_headers', where: 'client_id = ?', whereArgs: [saved.clientId])).single;
    expect((h['local_id'], h['server_id']), (saved.headerLocalId, 4));
    final d = await db.query('movement_details', where: 'header_local_id = ?', whereArgs: [saved.headerLocalId]);
    expect(d.map((x) => (x['server_id'], x['amount_cents'])), [(40, -1000)]);
    expect((await balances())[1], 49950 - 1000);
  });

  test('dos pulls simultáneos comparten uno solo', () async {
    final s = _Server(fullWindow());
    final svc = service(s);
    final res = await Future.wait([svc.pull(), svc.pull()]);
    expect(identical(res[0], res[1]), isTrue);
    expect(s.queries, hasLength(2)); // 2 páginas, no 4
  });
}
