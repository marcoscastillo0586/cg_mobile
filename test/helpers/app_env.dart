// Entorno para probar pantallas de formularios: base local REAL (ffi), servidor SIMULADO y los avisos que se
// recalculan después de guardar (saldos y novedades) sin efecto.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/dashboard/data/budget_alerts_repository.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/dashboard_notifier.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'local_seed.dart';
import 'screen.dart';

/// Servidor simulado: responde cada ruta con lo cargado en [routes] (path → (estado, cuerpo)); el resto, 503
/// (sin conexión). Guarda los pedidos.
class FakeServer implements HttpClientAdapter {
  final routes = <String, (int, Object)>{};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    final (status, body) = routes[o.path] ?? (503, {'statusCode': 503, 'code': 'TEMPORARY_ERROR', 'message': 'x'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _NoBalances implements BalancesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietDashboard extends DashboardNotifier {
  _QuietDashboard() : super(_NoBalances());
  @override
  Future<void> cargarDashboard({String? hasta}) async {}
}

class _QuietNovedades extends NovedadesNotifier {
  _QuietNovedades() : super(never(), SecureStorageService(const FlutterSecureStorage()), BudgetAlertsRepository(DioClient()), () => null);
  @override
  Future<void> calcularNovedades() async {}
}

/// Overrides para una pantalla que lee y escribe en [s] y habla con [server].
List<Override> localAppOverrides(SeededDb s, FakeServer server) {
  FlutterSecureStorage.setMockInitialValues({'is_first_launch_done': 'true'});
  ServerReachability.markOnline();
  return [
    localDatabaseProvider.overrideWithValue(Future.value(s.db)),
    localCatalogProvider.overrideWithValue(s.catalog),
    localMovementWriterProvider.overrideWithValue(s.writer),
    dioClientProvider.overrideWithValue(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1'),
    dashboardNotifierProvider.overrideWith((_) => _QuietDashboard()),
    novedadesNotifierProvider.overrideWith((_) => _QuietNovedades()),
  ];
}

/// La E/S de SQLite no avanza con el reloj simulado de los widget tests: se la deja correr y se repinta.
Future<void> settleIo(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
