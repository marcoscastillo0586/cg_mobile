// Reportes sin conexión calculados con la base del celular (SQLite REAL, ffi): mismas reglas y forma que la API.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/analytics/data/local_reports.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late LocalReports reports;
  late int unsentPan;
  late int nueva;
  var n = 0;

  Future<int> header(int? serverId, int type, String at) => s.db.insert('movement_headers', {
        'server_id': serverId,
        'client_id': serverId == null ? 'h-${n++}' : null,
        'type': type,
        'occurred_at': at,
        'updated_at': 'x',
      });
  Future<void> detail(int h, String account, int category, int cents, String concept, {String? plu, int? unit, int? serverId}) =>
      s.db.insert('movement_details', {
        'server_id': serverId,
        'header_local_id': h,
        'account_local_id': s.accounts[account],
        'category_local_id': category,
        'amount_cents': cents,
        'concept': concept,
        'plu': plu,
        'unit_price_cents': unit,
        'updated_at': 'x',
      });

  setUp(() async {
    // Base: ingresos del 01/01/2026 → Banco 1.000, Efectivo 50 (ARS) y Dolares US$100 (no cuenta en ARS).
    s = await seededDb();
    reports = LocalReports(s.db, currency: 'ARS');
    final comida = s.categories['Comida']!;
    final superCat = s.categories['Super']!;
    final vieja = await s.db.insert('categories', {'server_id': 50, 'name': 'Vieja', 'active': 0, 'updated_at': 'x'});
    nueva = await s.db.insert('categories', {'client_id': 'cat-nueva', 'name': 'Nueva', 'updated_at': 'x'});

    final e1 = await header(900, 2, '2026-10-05 10:00:00');
    await detail(e1, 'Banco', comida, -10000, 'Leche Entera', plu: '001', unit: 5000, serverId: 9001);
    await detail(e1, 'Banco', superCat, -3000, 'Pan', serverId: 9002);
    final e2 = await header(901, 2, '2026-10-20 10:00:00');
    await detail(e2, 'Efectivo', comida, -12000, 'LECHE ENTERA', plu: '001', unit: 6000, serverId: 9011);
    final usd = await header(902, 2, '2026-10-06 10:00:00');
    await detail(usd, 'Dolares', comida, -999, 'Leche USD', plu: '001', unit: 999, serverId: 9021);
    final income = await header(903, 1, '2026-10-01 09:00:00');
    await detail(income, 'Banco', s.categories['Ingreso']!, 50000, 'Sueldo', serverId: 9031);
    final chicle = await header(null, 2, '2026-10-25 10:00:00');
    await detail(chicle, 'Banco', nueva, -400, 'Chicle');
    unsentPan = await header(null, 2, '2026-11-02 10:00:00');
    await detail(unsentPan, 'Banco', superCat, -2000, 'Pan');
    final old = await header(904, 2, '2026-11-03 10:00:00');
    await detail(old, 'Banco', vieja, -700, 'Algo', serverId: 9041);
  });
  tearDown(() => s.db.close());

  const october = {'from': '2026-10-01', 'to': '2026-10-31'};
  List<List<Object?>> chart(Map<String, dynamic> r) => [for (final i in r['items'] as List) [(i as Map)['label'], i['amountCents'], i['categoryId']]];

  test('consumo por categoría: egresos en la moneda principal, de menor a mayor, categorías activas', () async {
    final r = await reports.byCategory(october);
    expect(chart(r), [['NUEVA', 400, -nueva], ['SUPER', 3000, 6], ['COMIDA', 22000, 5]]);
    expect(r, containsPair('totalCents', 25400));
    expect(r, containsPair('from', '2026-10-01'));
    expect(chart(await reports.byCategory({...october, 'accountIds': '2'})), [['COMIDA', 12000, 5]]);
    expect(chart(await reports.byCategory({'from': '2026-11-01', 'to': '2026-11-30'})), [['SUPER', 2000, 6]]);
  });

  test('período por defecto: el mes actual completo', () async {
    final now = DateTime.now();
    String two(int v) => '$v'.padLeft(2, '0');
    final r = await reports.byCategory({});
    expect(r['from'], '${now.year}-${two(now.month)}-01');
    expect(r['to'], '${now.year}-${two(now.month)}-${two(DateTime(now.year, now.month + 1, 0).day)}');
  });

  test('consumo por concepto: une mayúsculas/acentos; con varias categorías antepone la categoría', () async {
    expect(chart(await reports.byConceptInCategories({...october, 'categoryIds': '5'})), [['LECHE ENTERA', 22000, 5]]);
    expect(chart(await reports.byConceptInCategories({...october, 'categoryIds': '5,6'})), [
      ['SUPER : PAN', 3000, 6],
      ['COMIDA : LECHE ENTERA', 22000, 5],
    ]);
    expect(chart(await reports.byConceptInCategories({...october, 'categoryIds': '-$nueva'})), [['CHICLE', 400, -nueva]]);
    expect(await reports.byConceptInCategories(october), containsPair('items', isEmpty));
  });

  test('ingresos y egresos del año: meses, totales, mes mayor/menor y top de categorías', () async {
    final r = await reports.incomeExpense({'year': '2026'});
    expect(r['years'], [2026]);
    final months = (r['months'] as List).cast<Map<String, dynamic>>();
    expect(months, hasLength(12));
    expect(months[0], {'month': 1, 'incomeCents': 105000, 'expenseCents': 0, 'balanceCents': 105000, 'savingsRate': 100});
    expect(months[9], containsPair('expenseCents', 25400));
    expect(months[9], containsPair('savingsRate', 49.2));
    expect(months[10], containsPair('expenseCents', 2700));
    expect(months[1], containsPair('savingsRate', 0));
    expect(r['totals'], {
      'incomeCents': 155000,
      'expenseCents': 28100,
      'balanceCents': 126900,
      'savingsRate': 81.87,
      'monthlyAverageExpenseCents': 14050,
      'highestExpenseMonth': {'month': 10, 'amountCents': 25400},
      'lowestExpenseMonth': {'month': 11, 'amountCents': 2700},
    });
    final top = [for (final t in r['topCategories'] as List) [(t as Map)['name'], t['amountCents'], t['percent']]];
    expect(top, [['Comida', 22000, 78.29], ['Super', 5000, 17.79], ['Vieja', 700, 2.49], ['Nueva', 400, 1.42]]);
  });

  test('año sin movimientos: totales en cero y sin mes mayor/menor', () async {
    final r = await reports.incomeExpense({'year': 2020});
    expect(r['totals'], containsPair('highestExpenseMonth', isNull));
    expect(r['totals'], containsPair('monthlyAverageExpenseCents', 0));
    expect(r['totals'], containsPair('savingsRate', 0));
    expect(r['topCategories'], isEmpty);
  });

  test('por día: todos los días del mes con ingresos y egresos', () async {
    final r = await reports.daily({'year': 2026, 'month': '10'});
    final days = (r['days'] as List).cast<Map<String, dynamic>>();
    expect(days, hasLength(31));
    expect(days[0], {'day': 1, 'date': '2026-10-01', 'incomeCents': 50000, 'expenseCents': 0});
    expect(days[4], containsPair('expenseCents', 13000));
    expect(days[19], containsPair('expenseCents', 12000));
    expect(days[24], containsPair('expenseCents', 400));
    expect(((await reports.daily({'year': 2028, 'month': 2}))['days'] as List), hasLength(29));
  });

  test('productos: compras, precios, variación; orden por compras y última fecha; búsqueda y límite', () async {
    final all = await reports.products({});
    expect([for (final p in all) p['concept']], ['PAN', 'LECHE ENTERA', 'ALGO', 'CHICLE']);
    expect(all[1], {
      'concept': 'LECHE ENTERA',
      'plu': '001',
      'purchases': 2,
      'firstDate': '2026-10-05',
      'lastDate': '2026-10-20',
      'firstPriceCents': 5000,
      'lastPriceCents': 6000,
      'minPriceCents': 5000,
      'maxPriceCents': 6000,
      'variationPercent': 20.0,
      'lastAccount': 'Efectivo',
    });
    expect(all[0], containsPair('variationPercent', -33.3));
    expect(all[0], containsPair('minPriceCents', 2000));
    expect(all[0], containsPair('plu', isNull));
    expect([for (final p in await reports.products({'search': ' lech '})) p['concept']], ['LECHE ENTERA']);
    expect([for (final p in await reports.products({'search': '001'})) p['concept']], ['LECHE ENTERA']);
    expect([for (final p in await reports.products({'search': '%'})) p['concept']], isEmpty);
    expect(await reports.products({'limit': '1'}), hasLength(1));
  });

  test('historial de un producto por concepto o PLU', () async {
    final pan = await reports.productHistory({'concept': 'pan'});
    expect(pan, containsPair('concept', 'PAN'));
    expect(pan, containsPair('purchases', 2));
    expect([pan['initialPriceCents'], pan['currentPriceCents'], pan['minPriceCents'], pan['maxPriceCents'], pan['increasePercent']], [3000, 2000, 2000, 3000, -33.3]);
    expect([for (final h in pan['history'] as List) (h as Map)['headerId']], [900, -unsentPan]);
    final leche = await reports.productHistory({'plu': '001'});
    expect(leche, containsPair('concept', 'LECHE ENTERA'));
    expect(leche, containsPair('purchases', 2));
    expect((leche['history'] as List).first, containsPair('category', 'Comida'));
    final none = await reports.productHistory({'concept': 'nada'});
    expect([none['purchases'], none['minPriceCents'], none['increasePercent']], [0, 0, 0]);
  });

  test('comparación de productos por PLU entre dos períodos', () async {
    final r = await reports.compareProducts({'from1': '2026-10-01', 'to1': '2026-10-10', 'from2': '2026-10-11', 'to2': '2026-10-31'});
    expect(r['items'], [
      {'plu': '001', 'name': 'LECHE ENTERA', 'price1Cents': 5000, 'price2Cents': 6000, 'quantity2': 1, 'differenceCents': 1000, 'percent': 20.0},
    ]);
    expect(r['totals'], {'commonProducts': 1, 'averageInflation': 20.0});
    final none = await reports.compareProducts({'from1': '2026-10-01', 'to1': '2026-10-10', 'from2': '2026-10-11', 'to2': '2026-10-31', 'categoryIds': '6'});
    expect(none['totals'], {'commonProducts': 0, 'averageInflation': 0});
  });

  test('get: elige el reporte por ruta; uno sin versión sin conexión avisa NOT_AVAILABLE_OFFLINE', () async {
    expect(await reports.get('/reports/by-category', october), await reports.byCategory(october));
    expect(await reports.get('/reports/daily', {'year': 2026, 'month': 10}), await reports.daily({'year': 2026, 'month': 10}));
    for (final path in ['/reports/by-concept-in-categories', '/reports/income-expense', '/reports/products', '/reports/product-history', '/reports/compare-products']) {
      final params = {...october, 'categoryIds': '5', 'concept': 'pan', 'from1': '2026-10-01', 'to1': '2026-10-10', 'from2': '2026-10-11', 'to2': '2026-10-31'};
      expect(await reports.get(path, params), isNotNull, reason: path);
    }
    expect(() => reports.get('/reports/monthly', {}), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'NOT_AVAILABLE_OFFLINE')));
  });
}
