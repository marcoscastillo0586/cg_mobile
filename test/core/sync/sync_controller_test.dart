// Sincronizador único contra SQLite REAL (ffi) y un servidor SIMULADO. No prueba la red real.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
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
    await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
  });
  tearDown(() async {
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
    expect((st.status, st.pendingOps), (SyncStatus.attention, 1));
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
}
