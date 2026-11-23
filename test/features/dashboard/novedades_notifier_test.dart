// Campana de novedades de límites: qué se avisa, en qué orden y cómo se comparte "vista" con la web.
// SQLite REAL (ffi) para los límites, almacenamiento seguro SIMULADO y servidor SIMULADO.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/constants/app_colors.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/core/sync/local_ops.dart';
import 'package:gastos_mobile/features/dashboard/data/budget_alerts_repository.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/novedad_entity.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/limits_admin/data/local_budgets_repository.dart';
import '../../helpers/local_seed.dart';

class _Server implements HttpClientAdapter {
  List<Map<String, Object?>>? seen = [];
  final posted = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method == 'POST') {
      posted.add(o.data as Map<String, dynamic>);
      return ResponseBody.fromString('{}', 201, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final body = seen;
    return body == null
        ? ResponseBody.fromString(jsonEncode({'statusCode': 503, 'code': 'X', 'message': 'x'}), 503, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]})
        : ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

String _day(int offset) {
  final t = DateTime.parse(LocalOps.todayAr()).add(Duration(days: offset));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SeededDb s;
  late LocalBudgetsRepository budgets;
  late _Server server;
  late SecureStorageService storage;
  final today = LocalOps.todayAr();

  Future<void> gasto(String category, int cents) async {
    final h = await s.db.insert('movement_headers', {'client_id': 'h-$category-$cents', 'type': 2, 'occurred_at': '$today 10:00:00', 'updated_at': 'x'});
    await s.db.insert('movement_details', {
      'header_local_id': h, 'account_local_id': s.accounts['Banco'], 'category_local_id': s.categories[category],
      'amount_cents': -cents, 'updated_at': 'x',
    });
  }

  Future<int> limite(String category, int limit, {required String start, required String end, int? serverId}) async {
    await budgets.create(startDate: start, endDate: end, limitCents: limit, categoryIds: [s.categories[category]!], accountIds: [s.accounts['Banco']!]);
    final id = (await s.db.query('budgets', columns: ['local_id'], orderBy: 'local_id DESC', limit: 1)).single['local_id']! as int;
    if (serverId != null) await s.db.update('budgets', {'server_id': serverId}, where: 'local_id = ?', whereArgs: [id]);
    return id;
  }

  NovedadesNotifier notifier({int? user = 7}) =>
      NovedadesNotifier(Future.value(budgets), storage, BudgetAlertsRepository(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1'), () => user);

  setUp(() async {
    s = await seededDb();
    budgets = LocalBudgetsRepository(s.db);
    server = _Server();
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService(const FlutterSecureStorage());
    await s.db.insert('categories', {'server_id': 60, 'name': 'Ocio', 'updated_at': 'x'});
    s.categories['Ocio'] = (await s.db.query('categories', where: 'server_id = 60')).single['local_id']! as int;
    await gasto('Comida', 800);
    await gasto('Super', 1500);
    await gasto('Ocio', 100);
  });
  tearDown(() => s.db.close());

  test('avisa cerca (≥ 75 %), alcanzado (≥ 100 %) y vencido; mayor porcentaje primero, vencidos al final; no avisa futuros ni bajos', () async {
    await limite('Comida', 1000, start: _day(-5), end: _day(5), serverId: 501); // 80 %
    await limite('Super', 1000, start: _day(-5), end: _day(5), serverId: 502); // 150 %
    await limite('Ocio', 1000, start: _day(-30), end: today); // vencido hoy
    await limite('Ocio', 100, start: _day(3), end: _day(10)); // futuro
    await limite('Ocio', 100000, start: _day(-5), end: _day(5)); // 0,1 %
    final n = notifier();
    await n.calcularNovedades();
    expect([for (final x in n.state.novedades) (x.titulo, x.tipo, x.porcentaje)], [
      ('Super', NovedadTipo.alcanzado, 150),
      ('Comida', NovedadTipo.cerca, 80),
      ('Ocio', NovedadTipo.vencido, 10),
    ]);
    expect(n.state.isLoading, isFalse);
    expect(n.state.hasUnread, isTrue);
    expect(n.state.gravedadMaxColor, AppColors.rose);
  });

  test('vistas: las del servidor quedan guardadas; las marcadas sólo en el celular se envían; claves viejas se borran', () async {
    await limite('Comida', 1000, start: _day(-5), end: _day(5), serverId: 501);
    final superId = await limite('Super', 1000, start: _day(-5), end: _day(5), serverId: 502);
    final comidaKey = 'alerta_vista_7_501_cerca_${_day(-5)}_${_day(5)}';
    final superKey = 'alerta_vista_7_502_alcanzado_${_day(-5)}_${_day(5)}';
    await storage.writeValue(comidaKey, '1');
    await storage.writeValue('alerta_vista_7_999_cerca_2020-01-01_2020-01-31', '1'); // límite que ya no existe
    await storage.writeValue('alerta_vista_8_1_cerca_x_y', '1'); // de otro usuario
    server.seen = [{'budgetId': 502, 'kind': 'alcanzado', 'startDate': _day(-5), 'endDate': _day(5)}];
    final n = notifier();
    await n.calcularNovedades();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(n.state.novedades.every((x) => x.vista), isTrue);
    expect(n.state.hasUnread, isFalse);
    expect(n.state.gravedadMaxColor, Colors.grey);
    expect(await storage.readValue(superKey), '1');
    expect(server.posted, contains(equals({'budgetId': 501, 'kind': 'cerca', 'startDate': _day(-5), 'endDate': _day(5)})));
    expect(await storage.readValue('alerta_vista_7_999_cerca_2020-01-01_2020-01-31'), isNull);
    expect(await storage.readValue('alerta_vista_8_1_cerca_x_y'), '1');
    expect(superId, isPositive);
  });

  test('sin conexión valen sólo las vistas del celular y no se envía nada; marcar como vista guarda y envía', () async {
    await limite('Comida', 1000, start: _day(-5), end: _day(5), serverId: 501);
    await limite('Ocio', 50, start: _day(-5), end: _day(5)); // 200 %, sin id del servidor
    server.seen = null;
    final n = notifier();
    await n.calcularNovedades();
    expect(n.state.novedades.map((x) => x.vista), [false, false]);
    expect(n.state.gravedadMaxColor, AppColors.rose);
    final ocio = n.state.novedades.first;
    await n.marcarComoVista(ocio);
    expect(n.state.novedades.first.vista, isTrue);
    expect(n.state.gravedadMaxColor, AppColors.amber); // queda la de Comida (cerca)
    expect(server.posted, isEmpty); // sin id del servidor no se comparte
    await n.marcarComoVista(n.state.novedades.last);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.posted.single, containsPair('budgetId', 501));
  });

  test('sin sesión no hay novedades; si falla la base queda el error', () async {
    final none = notifier(user: null);
    await none.calcularNovedades();
    expect(none.state.novedades, isEmpty);
    final n = notifier();
    await s.db.close();
    await n.calcularNovedades();
    expect(n.state.novedades, isEmpty);
    expect(n.state.isLoading, isFalse);
    expect(n.state.error, isNotNull);
  });
}
