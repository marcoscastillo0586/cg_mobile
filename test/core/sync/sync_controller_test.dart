// Sincronizador único contra SQLite REAL (ffi) y un servidor SIMULADO. No prueba la red real.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/core/sync/outbox.dart';
import 'package:gastos_mobile/core/sync/pull_service.dart';
import 'package:gastos_mobile/core/sync/push_service.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/sync/sync_controller.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

class _Server implements HttpClientAdapter {
  final paths = <String>[];
  final gate = Completer<void>();
  String pushCode = 'TEMPORARY_ERROR';

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    paths.add(o.path);
    await gate.future; // deja la primera sincronización "en vuelo"
    final ops = ((o.data as Map)['operations'] as List).cast<Map<String, dynamic>>();
    final results = [
      for (final op in ops)
        {'opId': op['opId'], 'status': 'rejected', 'entity': 'movement', 'serverId': null, 'clientId': op['clientId'], 'version': null,
         'error': {'code': pushCode, 'message': 'x'}, 'current': null},
    ];
    return ResponseBody.fromString(jsonEncode({'serverTime': 'x', 'results': results}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late SeededDb s;
  late _Server server;
  late ProviderContainer container;

  setUp(() async {
    s = await seededDb();
    server = _Server();
    container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(Future.value(s.db)),
      dioClientProvider.overrideWithValue(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1'),
    ]);
    Outbox.takeRecent(); // la lista de recién guardados es global: cada test arranca con la suya
    await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
  });
  tearDown(() async {
    ServerReachability.markOnline();
    container.dispose();
    await s.db.close();
  });

  test('dos sincronizaciones a la vez comparten una sola; con error temporal no descarga y no informa éxito', () async {
    final ctrl = container.read(syncControllerProvider.notifier);
    final a = ctrl.sync(), b = ctrl.sync();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(syncControllerProvider).status, SyncStatus.syncing);
    server.gate.complete();
    await Future.wait([a, b]);
    expect(server.paths, ['/sync/push']); // un solo envío y sin pull
    final st = container.read(syncControllerProvider);
    // R2: el error temporal del servidor cuenta como "sin conexión" (sin avisos); lo pendiente sigue en la cola.
    expect((st.status, st.pendingOps), (SyncStatus.offline, 1));
    expect(st.lastPush!.issues.single.code, 'TEMPORARY_ERROR');
  });

  test('rechazo: estado "requiere atención" con el detalle y el conteo de rechazadas', () async {
    server.pushCode = 'INSUFFICIENT_FUNDS';
    server.gate.complete();
    final ctrl = container.read(syncControllerProvider.notifier);
    // El pull que sigue al push falla en este servidor simulado (no responde /sync/pull como se espera):
    // el estado debe ser error, nunca "completa".
    await ctrl.sync();
    final st = container.read(syncControllerProvider);
    expect(st.status, isNot(SyncStatus.complete));
    expect((st.rejectedOps, st.pendingOps), (1, 0));
  });

  test('estado al terminar: pendiente → sin conexión; rechazo → atención; diferencias; si no, completa', () {
    PushResult push(List<String> statuses) =>
        PushResult(sent: statuses.length, applied: 0, duplicate: 0, issues: [for (final (i, st) in statuses.indexed) PushIssue(i, st, null, null)]);
    const ok = PullResult(full: false, pages: 1, movementsApplied: 0, deletedApplied: 0, mismatches: []);
    const diff = PullResult(full: false, pages: 1, movementsApplied: 0, deletedApplied: 0, mismatches: [AccountMismatch(1, 'Banco', 1, 2, 1, 1)]);
    expect(SyncController.statusAfter(push(['pending', 'rejected']), null), SyncStatus.offline);
    expect(SyncController.statusAfter(push(['rejected']), ok), SyncStatus.attention);
    expect(SyncController.statusAfter(push([]), diff), SyncStatus.mismatch);
    expect(SyncController.statusAfter(push(['conflict']), ok), SyncStatus.complete);
    expect(SyncController.statusAfter(push([]), null), SyncStatus.complete);
  });

  group('conflictos: vale el último cambio', () {
    Future<void> conflict(String createdAt, Map<String, Object?> ref, {String entity = 'account'}) => s.db.insert('outbox', {
          'op_id': LocalDatabase.newId(),
          'entity': entity,
          'action': 'update',
          'ref': jsonEncode(ref),
          'base_version': 1,
          'data': jsonEncode({'name': 'Banco 2'}),
          'status': 'conflict',
          'created_at': createdAt,
          'updated_at': createdAt,
        });

    test('cambio del celular posterior al del servidor: se reenvía como operación nueva sobre la versión actual', () async {
      await s.db.delete('outbox');
      await s.db.update('accounts', {'version': 3, 'updated_at': '2026-10-21T10:00:00Z'}, where: 'server_id = 1');
      await conflict('2026-10-21T11:00:00Z', {'serverId': 1});
      final before = (await s.db.query('outbox')).single;
      expect(await SyncController.resolveConflicts(s.db), 1);
      final op = (await s.db.query('outbox')).single;
      expect(op['status'], 'pending');
      expect(op['base_version'], 3);
      expect(op['op_id'], isNot(before['op_id']));
      expect(op['data'], before['data']);
    });

    test('cambio del servidor posterior, registro inexistente o referencia sin id del servidor: se descarta', () async {
      await s.db.delete('outbox');
      await s.db.update('accounts', {'version': 3, 'updated_at': '2026-10-21T10:00:00Z'}, where: 'server_id = 1');
      await conflict('2026-10-21T09:00:00Z', {'serverId': 1});
      await conflict('2026-10-21T11:00:00Z', {'serverId': 999});
      await conflict('2026-10-21T11:00:00Z', {'clientId': 'local-1'});
      expect(await SyncController.resolveConflicts(s.db), 0);
      expect(await s.count('outbox'), 0);
    });
  });

  group('sendNow: envía ya lo recién guardado', () {
    test('rechazo por regla de negocio: lo devuelve y saca la operación de la cola', () async {
      server.pushCode = 'INSUFFICIENT_FUNDS';
      server.gate.complete();
      final rejection = await container.read(syncControllerProvider.notifier).sendNow();
      expect(rejection, isA<ServerException>().having((e) => e.code, 'code', 'INSUFFICIENT_FUNDS'));
      expect(await s.count('outbox'), 0);
      expect(container.read(syncControllerProvider).rejectedOps, 0);
    });

    test('sin conexión reciente o sin nada nuevo: no envía ni avisa', () async {
      ServerReachability.markOffline();
      expect(await container.read(syncControllerProvider.notifier).sendNow(), isNull);
      ServerReachability.markOnline();
      expect(await container.read(syncControllerProvider.notifier).sendNow(), isNull); // la cola reciente ya se tomó
      expect(server.paths, isEmpty);
    });

    test('error temporal: queda en la cola sin avisar', () async {
      server.gate.complete();
      expect(await container.read(syncControllerProvider.notifier).sendNow(), isNull);
      expect(await s.count('outbox', "status = 'pending'"), 1);
    });
  });

  test('conteos locales: pendientes y comprobantes sin enviar; si la base falla, queda el error', () async {
    final ctrl = container.read(syncControllerProvider.notifier);
    await ctrl.refreshCounts();
    final st = container.read(syncControllerProvider);
    expect((st.pendingOps, st.rejectedOps, st.conflictOps), (1, 0, 0));
    await s.db.close();
    await ctrl.refreshCounts();
    expect(container.read(syncControllerProvider).error, isNotNull);
  });
}
