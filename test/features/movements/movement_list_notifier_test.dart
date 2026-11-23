// Historial: paginación, filtros y respuestas viejas descartadas, con un servidor SIMULADO que pagina.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/movements/data/movements_repository.dart';
import 'package:gastos_mobile/features/movements/presentation/providers/movement_list_notifier.dart';
import 'package:gastos_mobile/features/movements/presentation/providers/movement_list_state.dart';

/// 60 movimientos; responde la página pedida (limit/offset). [fallar] devuelve un error; [gate] demora.
class _Paginado implements HttpClientAdapter {
  final queries = <Map<String, dynamic>>[];
  bool fallar = false;
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    queries.add(o.queryParameters);
    await gate?.future;
    if (fallar) return _json(500, {'statusCode': 500, 'code': 'INTERNAL_ERROR', 'message': 'x'});
    final limit = o.queryParameters['limit'] as int, offset = o.queryParameters['offset'] as int;
    final ids = [for (var i = offset; i < 60 && i < offset + limit; i++) i + 1];
    return _json(200, {
      'items': [
        for (final id in ids)
          {'id': id, 'type': 2, 'occurredAt': '2026-10-10 10:00:00', 'details': <Object>[], 'detailsCount': 0, 'amountCents': -100},
      ],
      'total': 60, 'limit': limit, 'offset': offset, 'hasMore': offset + limit < 60, 'filteredTotalCents': -6000,
    });
  }

  static ResponseBody _json(int status, Object body) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Paginado server;
  late MovementListNotifier n;

  setUp(() {
    server = _Paginado();
    n = MovementListNotifier(MovementsRepository(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1'));
  });

  test('primera página y "cargar más" hasta el final; sin más, no consulta', () async {
    await n.cargarMovimientos();
    expect((n.state.movimientos.length, n.state.hasMore, n.state.total), (50, true, 60));
    await n.cargarMas();
    expect((n.state.movimientos.length, n.state.hasMore, n.state.loadingMore), (60, false, false));
    expect(server.queries.last['offset'], 50);
    await n.cargarMas();
    expect(server.queries, hasLength(2));
  });

  test('"cargar más" con error conserva lo cargado y guarda el motivo', () async {
    await n.cargarMovimientos();
    server.fallar = true;
    await n.cargarMas();
    expect((n.state.movimientos.length, n.state.loadingMore, n.state.error != null), (50, false, true));
  });

  test('"cargar más" mientras carga o mientras ya pide otra página no repite el pedido', () async {
    await n.cargarMovimientos();
    server.gate = Completer();
    final primera = n.cargarMas();
    await n.cargarMas();
    server.gate!.complete();
    await primera;
    expect(server.queries, hasLength(2));
  });

  test('una búsqueda nueva descarta la página que llegaba de la anterior', () async {
    await n.cargarMovimientos();
    server.gate = Completer();
    final vieja = n.cargarMas();
    final nueva = n.setBusqueda(' pan ');
    server.gate!.complete();
    await Future.wait([vieja, nueva]);
    expect(n.state.movimientos.length, 50); // la página 2 de la búsqueda anterior no se sumó
    expect(server.queries.last['q'], 'pan');
  });

  test('filtros: cuenta, rango y limpiarlos; primera carga con error', () async {
    await n.inicializar(idCuenta: 3, nombreCuenta: 'Banco');
    expect(server.queries.last['accountIds'], '3');
    await n.setRango('2026-10-01', '2026-10-31');
    expect((server.queries.last['from'], server.queries.last['to']), ('2026-10-01', '2026-10-31'));
    await n.limpiarFiltroFechas();
    expect(server.queries.last.containsKey('from'), isFalse);
    await n.limpiarFiltroCuenta();
    expect(server.queries.last.containsKey('accountIds'), isFalse);
    server.fallar = true;
    await n.cargarMovimientos();
    expect(n.state.status, MovementListStatus.error);
  });
}
