// Respuestas SIMULADAS con la forma de los DTO de reportes (@cg/shared). Prueban rutas,
// parámetros y parseo en centavos; no la API real (eso lo hace la verificación en vivo).
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/analytics/data/reports_repository.dart';

class _FakeApi implements HttpClientAdapter {
  final Map<String, Object> responses;
  final List<Uri> requests = [];
  _FakeApi(this.responses);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o.uri);
    final body = responses[o.path];
    if (body == null) {
      return ResponseBody.fromString(jsonEncode({'statusCode': 404, 'code': 'NOT_FOUND', 'message': 'x'}), 404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

(ReportsRepository, _FakeApi) _repo(Map<String, Object> responses) {
  final api = _FakeApi(responses);
  final client = DioClient(adapter: api)..dio.options.baseUrl = 'http://api.fake/api/v1';
  return (ReportsRepository(client), api);
}

void main() {
  test('por categoría + desglose por concepto de esas categorías', () async {
    final (repo, api) = _repo({
      '/reports/by-category': {
        'from': '2026-10-01',
        'to': '2026-10-31',
        'totalCents': 400000,
        'items': [
          {'label': 'Super', 'amountCents': 100000, 'categoryId': 7},
          {'label': 'Comida', 'amountCents': 300000, 'categoryId': 3},
        ],
      },
      '/reports/by-concept-in-categories': {
        'from': '2026-10-01',
        'to': '2026-10-31',
        'totalCents': 400000,
        'items': [
          {'label': 'COMIDA : Pan', 'amountCents': 300000},
          {'label': 'SUPER : Yerba', 'amountCents': 100000},
        ],
      },
    });
    final r = await repo.getCategoryReport(from: '2026-10-01', to: '2026-10-31', accountIds: [5]);
    expect(r.totalCents, 400000);
    expect(r.categorias.map((c) => c.nombre), ['Comida', 'Super']); // mayor monto primero
    expect(r.categorias.first.porcentaje, 75);
    expect(r.subcategorias.first.etiqueta, 'COMIDA : Pan');
    final sub = api.requests.last;
    expect(sub.path, '/api/v1/reports/by-concept-in-categories');
    // El orden de categoryIds no importa para la API: se comparan como conjunto.
    expect(sub.queryParameters['categoryIds']!.split(',').toSet(), {'7', '3'});
    expect(sub.queryParameters['accountIds'], '5');
  });

  test('ingresos/egresos/ahorro por mes', () async {
    final (repo, _) = _repo({
      '/reports/income-expense': {
        'year': 2026,
        'years': [2025, 2026],
        'months': [
          {'month': 1, 'incomeCents': 500000, 'expenseCents': 200000, 'balanceCents': 300000, 'savingsRate': 60},
        ],
        'totals': {
          'incomeCents': 500000,
          'expenseCents': 200000,
          'balanceCents': 300000,
          'savingsRate': 60,
          'monthlyAverageExpenseCents': 200000,
          'highestExpenseMonth': {'month': 1, 'amountCents': 200000},
          'lowestExpenseMonth': null,
        },
        'topCategories': [
          {'categoryId': 3, 'name': 'Comida', 'amountCents': 200000, 'percent': 100},
        ],
      },
    });
    final r = await repo.getIncomeExpense(year: 2026);
    expect(r.meses.single.balanceCents, 300000);
    expect(r.meses.single.nombreMesTexto, 'Enero');
    expect(r.totalesAnuales.mesMayorGasto!.nombre, 'Enero');
    expect(r.totalesAnuales.mesMenorGasto, isNull);
    expect(r.topCategorias.single.montoCents, 200000);
  });

  test('evolución diaria: totales y máximo en centavos', () async {
    final (repo, api) = _repo({
      '/reports/daily': {
        'year': 2026,
        'month': 10,
        'days': [
          {'day': 1, 'date': '2026-10-01', 'incomeCents': 0, 'expenseCents': 1050},
          {'day': 2, 'date': '2026-10-02', 'incomeCents': 99999, 'expenseCents': 3000},
        ],
      },
    });
    final r = await repo.getDaily(year: 2026, month: 10);
    expect(r.totalEgresosMesCents, 4050);
    expect(r.totalIngresosMesCents, 99999);
    expect(r.maximoGastoDiarioCents, 3000);
    expect(api.requests.single.queryParameters, {'year': '2026', 'month': '10'});
  });

  test('comparativa por PLU: productos que subieron', () async {
    final (repo, _) = _repo({
      '/reports/compare-products': {
        'items': [
          {'plu': '1', 'name': 'A', 'price1Cents': 1000, 'price2Cents': 1200, 'quantity2': 2, 'differenceCents': 200, 'percent': 20},
          {'plu': '2', 'name': 'B', 'price1Cents': 1000, 'price2Cents': 900, 'quantity2': 1, 'differenceCents': -100, 'percent': -10},
        ],
        'totals': {'commonProducts': 2, 'averageInflation': 5},
      },
    });
    final r = await repo.compareProducts(from1: '2026-09-01', to1: '2026-09-30', from2: '2026-10-01', to2: '2026-10-31');
    expect(r.productosAumentaron, 1);
    expect(r.comparativa.first.diferenciaCents, 200);
  });

  test('importe con decimales en un reporte: error de contrato', () async {
    final (repo, _) = _repo({
      '/reports/daily': {
        'year': 2026,
        'month': 10,
        'days': [
          {'day': 1, 'date': '2026-10-01', 'incomeCents': 0, 'expenseCents': 10.5},
        ],
      },
    });
    await expectLater(repo.getDaily(year: 2026, month: 10), throwsA(isA<ServerException>()));
  });
}
