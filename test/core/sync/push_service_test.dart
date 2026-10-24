// SQLite REAL (ffi) + servidor SIMULADO que imita sync.service.ts (idempotencia por opId,
// TEMPORARY_ERROR sin registrar, rechazos y conflictos). No prueba la red ni el servidor
// reales: eso se verifica en el celular contra la API de pruebas.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/sync/push_service.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

typedef Decide = Map<String, dynamic> Function(Map<String, dynamic> op);

class _SyncServer implements HttpClientAdapter {
  /// Resultado por operación nueva (no llamado para opIds ya registrados).
  Decide decide;

  /// Si es true, el servidor procesa el lote pero la respuesta "se pierde" (corte de red).
  bool dropResponse = false;
  int status = 200;
  final processed = <String, Map<String, dynamic>>{}; // sync_operations
  final requests = <List<Map<String, dynamic>>>[];
  int nextId = 9000;

  _SyncServer(this.decide);

  Map<String, dynamic> applied(Map<String, dynamic> op) =>
      {'opId': op['opId'], 'status': 'applied', 'entity': op['entity'], 'serverId': nextId++, 'clientId': op['clientId'], 'version': 1, 'error': null, 'current': null};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final ops = ((o.data as Map)['operations'] as List).cast<Map<String, dynamic>>();
    requests.add(ops);
    if (status != 200) {
      return ResponseBody.fromString(jsonEncode({'statusCode': status, 'code': 'VALIDATION_ERROR', 'message': 'lote inválido'}), status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final results = <Map<String, dynamic>>[];
    for (final op in ops) {
      final prev = processed[op['opId']];
      if (prev != null) {
        results.add({...prev, 'status': prev['status'] == 'applied' ? 'duplicate' : prev['status']});
        continue;
      }
      final r = decide(op);
      final temporary = (r['error'] as Map?)?['code'] == 'TEMPORARY_ERROR';
      if (!temporary) processed[op['opId'] as String] = r;
      results.add(r);
    }
    if (dropResponse) throw DioException.connectionError(requestOptions: o, reason: 'corte de red después de procesar (simulado)');
    return ResponseBody.fromString(jsonEncode({'serverTime': 'x', 'results': results}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> rejected(Map<String, dynamic> op, String code) =>
    {'opId': op['opId'], 'status': 'rejected', 'entity': op['entity'], 'serverId': null, 'clientId': op['clientId'], 'version': null, 'error': {'code': code, 'message': 'motivo $code'}, 'current': null};

void main() {
  late SeededDb s;
  late _SyncServer server;
  setUp(() async {
    s = await seededDb();
    server = _SyncServer((op) => server.applied(op));
  });
  tearDown(() => s.db.close());

  PushService push({int batch = 100}) =>
      PushService(s.db, DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1', batchSize: batch);

  Future<SavedMovement> gasto(int cents, {String account = 'Banco'}) async => (await s.writer).createExpense(ExpenseDraft(
      accountLocalId: s.accounts[account]!, date: DateTime(2026, 10, 21), generalConcept: 'offline',
      lines: [ExpenseLine(concept: 'pan', categoryLocalId: s.categories['Comida']!, amountCents: cents)]));

  Future<Map<String, Object?>> op(String opId) async => (await s.db.query('outbox', where: 'op_id = ?', whereArgs: [opId])).single;
  Future<Map<String, Object?>> header(int localId) async => (await s.db.query('movement_headers', where: 'local_id = ?', whereArgs: [localId])).single;

  test('applied: remapea clientId → serverId, guarda la versión y envía opId/clientId estables', () async {
    final m = await gasto(1000);
    final r = await push().push();
    expect((r.sent, r.applied, r.complete), (1, 1, true));
    final sentOp = server.requests.single.single;
    expect((sentOp['opId'], sentOp['clientId'], sentOp['entity'], sentOp['action']), (m.opId, m.clientId, 'movement', 'create'));
    final h = await header(m.headerLocalId);
    expect((h['server_id'], h['version'], h['client_id']), (9000, 1, m.clientId));
    expect((await op(m.opId))['status'], 'applied');
    expect(await s.balance('Banco'), 100000 - 1000); // sigue contando
  });

  test('corte de red con el servidor ya aplicado: queda pendiente y el reintento (mismo opId) da duplicate, sin repetir', () async {
    final m = await gasto(1000);
    server.dropResponse = true;
    await expectLater(push().push(), throwsA(isA<NetworkException>()));
    final pend = await op(m.opId);
    expect((pend['status'], pend['attempts']), ('pending', 1));
    expect((await header(m.headerLocalId))['server_id'], isNull);

    server.dropResponse = false;
    final r = await push().push();
    expect((r.duplicate, r.complete), (1, true));
    expect(server.requests.map((b) => b.single['opId']), [m.opId, m.opId]); // mismo opId
    expect(server.processed, hasLength(1)); // una sola fila en sync_operations
    expect((await header(m.headerLocalId))['server_id'], 9000);
    expect((await op(m.opId))['attempts'], 2);
  });

  test('TEMPORARY_ERROR: queda pendiente con el mismo opId y se aplica en el próximo envío', () async {
    final m = await gasto(1000);
    server.decide = (o) => rejected(o, 'TEMPORARY_ERROR');
    final r1 = await push().push();
    expect((r1.complete, r1.count('pending')), (false, 1));
    expect((await op(m.opId))['status'], 'pending');
    server.decide = (o) => server.applied(o);
    final r2 = await push().push();
    expect((r2.applied, r2.complete), (1, true));
    expect(server.requests.map((b) => b.single['opId']).toSet(), {m.opId});
  });

  test('rejected ACCOUNT_INACTIVE: el saldo local se revierte, queda visible y no se reenvía', () async {
    final m = await gasto(4000, account: 'Efectivo');
    expect(await s.balance('Efectivo'), 1000);
    server.decide = (o) => rejected(o, 'ACCOUNT_INACTIVE');
    final r = await push().push();
    expect((r.complete, r.issues.single.code), (false, 'ACCOUNT_INACTIVE'));
    expect(await s.balance('Efectivo'), 5000); // revertido
    final o = await op(m.opId);
    expect(o['status'], 'rejected');
    expect((jsonDecode(o['server_result']! as String) as Map)['error'], {'code': 'ACCOUNT_INACTIVE', 'message': 'motivo ACCOUNT_INACTIVE'});
    expect((await header(m.headerLocalId))['deleted'], 1);
    final again = await push().push();
    expect(again.sent, 0);
  });

  test('referencias: la operación siguiente pasa de {clientId} a {serverId} tras aplicarse el alta', () async {
    final m = await gasto(1000);
    final upd = await (await s.editor).updateHeader(m.headerLocalId, generalConcept: 'nuevo');
    expect((await op(upd))['ref'], jsonEncode({'clientId': m.clientId}));
    server.decide = (o) => o['action'] == 'create' ? server.applied(o) : rejected(o, 'TEMPORARY_ERROR');
    await push(batch: 1).push();
    expect((await op(upd))['ref'], jsonEncode({'serverId': 9000}));
    server.decide = (o) => server.applied(o);
    await push().push();
    expect(server.requests.last.single['ref'], {'serverId': 9000});
  });

  test('conflict: gana el servidor (se aplica current) y la operación queda para resolver', () async {
    // Comprobante ya sincronizado (server_id 101, versión 1) que se edita en el celular.
    final hid = (await s.db.query('movement_headers', where: 'server_id = 101')).single['local_id']! as int;
    await s.db.update('movement_headers', {'version': 1, 'general_concept': 'original'}, where: 'local_id = ?', whereArgs: [hid]);
    final upd = await (await s.editor).updateHeader(hid, generalConcept: 'desde el celular');
    expect(server.requests, isEmpty);
    server.decide = (o) => {
          'opId': o['opId'], 'status': 'conflict', 'entity': 'movement', 'serverId': 101, 'clientId': null, 'version': 2,
          'error': {'code': 'VERSION_CONFLICT', 'message': 'El registro cambió en el servidor'},
          'current': {
            'id': 101, 'type': 1, 'occurredAt': '2026-01-01 10:00:00', 'generalConcept': 'desde la web', 'partialDetails': false,
            'details': [
              {'id': 101, 'accountId': 1, 'categoryId': null, 'concept': null, 'amountCents': 100000, 'plu': null, 'unitPriceCents': null, 'imageUrl': null},
            ],
          },
        };
    final r = await push().push();
    expect(server.requests.single.single['baseVersion'], 1);
    expect((r.count('conflict'), r.complete), (1, false));
    final h = await header(hid);
    expect((h['general_concept'], h['version']), ('desde la web', 2));
    expect((await op(upd))['status'], 'conflict');
  });

  test('edición rechazada: los valores locales vuelven a los de antes (undo)', () async {
    final hid = (await s.db.query('movement_headers', where: 'server_id = 101')).single['local_id']! as int;
    await s.db.update('movement_headers', {'version': 1, 'general_concept': 'original'}, where: 'local_id = ?', whereArgs: [hid]);
    await (await s.editor).updateHeader(hid, generalConcept: 'x', date: DateTime(2026, 2, 3));
    expect(((await header(hid))['general_concept'], (await header(hid))['occurred_at']), ('x', '2026-02-03 10:00:00'));
    server.decide = (o) => rejected(o, 'VALIDATION_ERROR');
    await push().push();
    expect(((await header(hid))['general_concept'], (await header(hid))['occurred_at']), ('original', '2026-01-01 10:00:00'));
  });

  test('lote rechazado entero (400): se reenvía de a una y solo la inválida queda rechazada', () async {
    final a = await gasto(100), b = await gasto(200);
    var calls = 0;
    server = _SyncServer((op) => server.applied(op));
    final adapter = _Batch400(server, () => calls++);
    final svc = PushService(s.db, DioClient(adapter: adapter)..dio.options.baseUrl = 'http://api.fake/api/v1');
    adapter.badOpId = b.opId;
    final r = await svc.push();
    expect(calls, 3); // lote + 2 individuales
    expect((await op(a.opId))['status'], 'applied');
    expect((await op(b.opId))['status'], 'rejected');
    expect(r.issues.single.code, 'VALIDATION_ERROR');
  });

  test('error de sesión o del servidor (5xx) corta el envío y deja todo pendiente', () async {
    final m = await gasto(100);
    server.status = 500;
    await expectLater(push().push(), throwsA(isA<ServerException>()));
    expect((await op(m.opId))['status'], 'pending');
  });
}

/// Responde 400 al lote si contiene [badOpId]; si no, delega en el servidor simulado.
class _Batch400 implements HttpClientAdapter {
  final _SyncServer inner;
  final void Function() onCall;
  String? badOpId;
  _Batch400(this.inner, this.onCall);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    onCall();
    final ops = ((o.data as Map)['operations'] as List).cast<Map<String, dynamic>>();
    if (ops.any((op) => op['opId'] == badOpId)) {
      return ResponseBody.fromString(jsonEncode({'statusCode': 400, 'code': 'VALIDATION_ERROR', 'message': 'opId inválido'}), 400,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return inner.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}
