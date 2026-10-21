import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/category_expense_report_entity.dart';
import '../domain/entities/daily_evolution_entity.dart';
import '../domain/entities/monthly_comparison_entity.dart';
import '../domain/entities/product_price_entity.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dioClientProvider));
});

/// Reportes de la API (`/reports/*`). Solo lectura; importes en centavos.
class ReportsRepository {
  final DioClient _client;
  ReportsRepository(this._client);

  /// Gasto por categoría (F8.1) y desglose por concepto de esas categorías (F8.2).
  Future<CategoryExpenseReportEntity> getCategoryReport({String? from, String? to, List<int> accountIds = const []}) async {
    final filter = {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (accountIds.isNotEmpty) 'accountIds': accountIds.join(','),
    };
    final chart = _map(await _client.get('/reports/by-category', queryParameters: filter), 'by-category');
    final total = Money.centsFrom(chart['totalCents'], 'totalCents');
    final items = _list(chart['items'], 'items').map((e) => _map(e, 'item')).toList();
    final categorias = items
        .map((i) => CategoryExpenseItemEntity(
              idCategoria: i['categoryId'] as int?,
              nombre: i['label'] as String? ?? '',
              montoCents: Money.centsFrom(i['amountCents'], 'item.amountCents'),
              porcentaje: _pct(Money.centsFrom(i['amountCents'], 'item.amountCents'), total),
            ))
        .toList()
      ..sort((a, b) => b.montoCents.compareTo(a.montoCents));

    final ids = categorias.map((c) => c.idCategoria).whereType<int>().toList();
    var subcategorias = <SubcategoryExpenseItemEntity>[];
    if (ids.isNotEmpty) {
      final sub = _map(
        await _client.get('/reports/by-concept-in-categories', queryParameters: {...filter, 'categoryIds': ids.join(',')}),
        'by-concept-in-categories',
      );
      final subTotal = Money.centsFrom(sub['totalCents'], 'totalCents');
      subcategorias = _list(sub['items'], 'items')
          .map((e) => _map(e, 'item'))
          .map((i) => SubcategoryExpenseItemEntity(
                etiqueta: i['label'] as String? ?? '',
                montoCents: Money.centsFrom(i['amountCents'], 'item.amountCents'),
                porcentaje: _pct(Money.centsFrom(i['amountCents'], 'item.amountCents'), subTotal),
              ))
          .toList()
        ..sort((a, b) => b.montoCents.compareTo(a.montoCents));
    }
    return CategoryExpenseReportEntity(
      desde: chart['from'] as String? ?? '',
      hasta: chart['to'] as String? ?? '',
      totalCents: total,
      categorias: categorias,
      subcategorias: subcategorias,
    );
  }

  /// Ingresos, egresos y ahorro por mes de un año (`/reports/income-expense`).
  Future<MonthlyComparisonReportEntity> getIncomeExpense({int? year}) async {
    final m = _map(await _client.get('/reports/income-expense', queryParameters: {if (year != null) 'year': year}), 'income-expense');
    final totals = _map(m['totals'], 'totals');
    MonthExtremeEntity? extreme(Object? v) {
      if (v == null) return null;
      final e = _map(v, 'extreme');
      return MonthExtremeEntity(mes: _int(e['month'], 'month'), montoCents: Money.centsFrom(e['amountCents'], 'amountCents'));
    }

    return MonthlyComparisonReportEntity(
      anio: _int(m['year'], 'year'),
      aniosDisponibles: _list(m['years'], 'years').map((y) => _int(y, 'years')).toList(),
      meses: _list(m['months'], 'months').map((e) => _map(e, 'month')).map((x) => MonthFinancialDataEntity(
            mes: _int(x['month'], 'month'),
            ingresosCents: Money.centsFrom(x['incomeCents'], 'incomeCents'),
            egresosCents: Money.centsFrom(x['expenseCents'], 'expenseCents'),
            balanceCents: Money.centsFrom(x['balanceCents'], 'balanceCents'),
            tasaAhorro: _num(x['savingsRate'], 'savingsRate'),
          )).toList(),
      totalesAnuales: AnnualTotalsEntity(
        totalIngresosCents: Money.centsFrom(totals['incomeCents'], 'totals.incomeCents'),
        totalEgresosCents: Money.centsFrom(totals['expenseCents'], 'totals.expenseCents'),
        balanceNetoCents: Money.centsFrom(totals['balanceCents'], 'totals.balanceCents'),
        tasaAhorroPorcentaje: _num(totals['savingsRate'], 'totals.savingsRate'),
        promedioMensualGastoCents: Money.centsFrom(totals['monthlyAverageExpenseCents'], 'monthlyAverageExpenseCents'),
        mesMayorGasto: extreme(totals['highestExpenseMonth']),
        mesMenorGasto: extreme(totals['lowestExpenseMonth']),
      ),
      topCategorias: _list(m['topCategories'], 'topCategories').map((e) => _map(e, 'topCategory')).map((c) => AnnualTopCategoryEntity(
            idCategoria: _int(c['categoryId'], 'categoryId'),
            nombre: c['name'] as String? ?? '',
            montoCents: Money.centsFrom(c['amountCents'], 'amountCents'),
            porcentaje: _num(c['percent'], 'percent'),
          )).toList(),
    );
  }

  Future<DailyEvolutionReportEntity> getDaily({required int year, required int month}) async {
    final m = _map(await _client.get('/reports/daily', queryParameters: {'year': year, 'month': month}), 'daily');
    return DailyEvolutionReportEntity(
      anio: _int(m['year'], 'year'),
      mes: _int(m['month'], 'month'),
      dias: _list(m['days'], 'days').map((e) => _map(e, 'day')).map((d) => DailyEvolutionItemEntity(
            dia: _int(d['day'], 'day'),
            fecha: d['date'] as String? ?? '',
            ingresosCents: Money.centsFrom(d['incomeCents'], 'incomeCents'),
            egresosCents: Money.centsFrom(d['expenseCents'], 'expenseCents'),
          )).toList(),
    );
  }

  Future<List<ProductPriceItemEntity>> getProducts({String? search, int limit = 50}) async {
    final data = await _client.get('/reports/products', queryParameters: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': limit,
    });
    return _list(data, 'products').map((e) => _map(e, 'product')).map((p) => ProductPriceItemEntity(
          concepto: p['concept'] as String? ?? '',
          plu: p['plu'] as String?,
          totalCompras: _int(p['purchases'], 'purchases'),
          ultimoPrecioCents: Money.centsFrom(p['lastPriceCents'], 'lastPriceCents'),
          primerPrecioCents: Money.centsFrom(p['firstPriceCents'], 'firstPriceCents'),
          precioMinimoCents: Money.centsFrom(p['minPriceCents'], 'minPriceCents'),
          precioMaximoCents: Money.centsFrom(p['maxPriceCents'], 'maxPriceCents'),
          variacionPorcentaje: _num(p['variationPercent'], 'variationPercent'),
          ultimaFecha: p['lastDate'] as String? ?? '',
          primeraFecha: p['firstDate'] as String? ?? '',
          ultimoLugar: p['lastAccount'] as String? ?? '',
        )).toList();
  }

  Future<ProductPriceHistoryEntity> getProductHistory({String? concept, String? plu}) async {
    final m = _map(
      await _client.get('/reports/product-history', queryParameters: {
        if (concept != null && concept.isNotEmpty) 'concept': concept,
        if (plu != null && plu.isNotEmpty) 'plu': plu,
      }),
      'product-history',
    );
    return ProductPriceHistoryEntity(
      concepto: m['concept'] as String? ?? '',
      cantidadCompras: _int(m['purchases'], 'purchases'),
      precioActualCents: Money.centsFrom(m['currentPriceCents'], 'currentPriceCents'),
      precioInicialCents: Money.centsFrom(m['initialPriceCents'], 'initialPriceCents'),
      precioMinimoCents: Money.centsFrom(m['minPriceCents'], 'minPriceCents'),
      precioMaximoCents: Money.centsFrom(m['maxPriceCents'], 'maxPriceCents'),
      aumentoPorcentaje: _num(m['increasePercent'], 'increasePercent'),
      historial: _list(m['history'], 'history').map((e) => _map(e, 'history')).map((h) => ProductPurchaseHistoryItemEntity(
            idMovimientoEnc: _int(h['headerId'], 'headerId'),
            fechaHora: h['occurredAt'] as String? ?? '',
            lugarNombre: h['account'] as String? ?? '',
            categoriaNombre: h['category'] as String?,
            concepto: h['concept'] as String? ?? '',
            precioUnitarioCents: Money.centsFrom(h['unitPriceCents'], 'unitPriceCents'),
            montoTotalCents: Money.centsFrom(h['totalCents'], 'totalCents'),
          )).toList(),
    );
  }

  /// Inflación por PLU entre dos períodos (F8.6). Fechas `yyyy-MM-dd`.
  Future<PriceComparisonResultEntity> compareProducts({
    required String from1,
    required String to1,
    required String from2,
    required String to2,
  }) async {
    final m = _map(
      await _client.get('/reports/compare-products', queryParameters: {'from1': from1, 'to1': to1, 'from2': from2, 'to2': to2}),
      'compare-products',
    );
    final totals = _map(m['totals'], 'totals');
    return PriceComparisonResultEntity(
      productosComunes: _int(totals['commonProducts'], 'commonProducts'),
      inflacionPromedio: _num(totals['averageInflation'], 'averageInflation'),
      comparativa: _list(m['items'], 'items').map((e) => _map(e, 'item')).map((i) => PriceComparisonItemEntity(
            plu: i['plu'] as String? ?? '',
            producto: i['name'] as String? ?? '',
            precio1Cents: Money.centsFrom(i['price1Cents'], 'price1Cents'),
            precio2Cents: Money.centsFrom(i['price2Cents'], 'price2Cents'),
            diferenciaCents: Money.centsFrom(i['differenceCents'], 'differenceCents'),
            porcentaje: _num(i['percent'], 'percent'),
            cantidadPeriodo2: _num(i['quantity2'], 'quantity2'),
          )).toList(),
    );
  }

  static double _pct(int part, int total) => total == 0 ? 0 : part * 100 / total;

  static Map<String, dynamic> _map(Object? v, String f) => v is Map<String, dynamic> ? v : throw _bad(f);
  static List<dynamic> _list(Object? v, String f) => v is List ? v : throw _bad(f);
  static int _int(Object? v, String f) => v is int ? v : throw _bad(f);
  static num _num(Object? v, String f) => v is num ? v : throw _bad(f);

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
