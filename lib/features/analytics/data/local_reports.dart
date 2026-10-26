import 'package:sqflite/sqflite.dart';
import '../../../core/errors/exceptions.dart';

/// Reportes (`/reports/*`) calculados con la base del celular, para usarlos sin conexión.
/// Mismas reglas que reports.service.ts del servidor y la misma forma de respuesta, para usar el
/// mismo parser. Incluye lo cargado en el celular que todavía no llegó al servidor.
///
/// Ids devueltos: los del servidor; lo que todavía no llegó usa el id local en negativo.
/// Los filtros de cuentas y categorías reciben esos mismos ids.
class LocalReports {
  final DatabaseExecutor _db;

  /// Moneda principal ('ARS' | 'USD'): como el servidor, solo cuentan las cuentas de esa moneda.
  final String currency;
  LocalReports(this._db, {required this.currency});

  /// Renglón de una cuenta en la moneda principal (parámetro: [currency]).
  static const _inCurrency = 'EXISTS (SELECT 1 FROM accounts ac WHERE ac.local_id = d.account_local_id AND ac.currency = ?)';

  Future<Object> get(String path, Map<String, dynamic> params) => switch (path) {
        '/reports/by-category' => byCategory(params),
        '/reports/by-concept-in-categories' => byConceptInCategories(params),
        '/reports/income-expense' => incomeExpense(params),
        '/reports/daily' => daily(params),
        '/reports/products' => products(params),
        '/reports/product-history' => productHistory(params),
        '/reports/compare-products' => compareProducts(params),
        _ => throw ServerException('Reporte sin versión sin conexión: $path', null, 'NOT_AVAILABLE_OFFLINE'),
      };

  // ---------------- gráficos de consumo ----------------

  /// Σ(−monto) por categoría.
  Future<Map<String, dynamic>> byCategory(Map<String, dynamic> params) async {
    final p = _period(params);
    final (where, args) = _expenseWhere(p, _ids(params['accountIds']));
    final rows = await _db.rawQuery('''
      SELECT c.name AS label, c.server_id AS c_sid, c.local_id AS c_lid, SUM(-d.amount_cents) AS amount
      $_from
      WHERE $where
      GROUP BY c.local_id
      ORDER BY COALESCE(c.server_id, 1000000000000 + c.local_id)''', args);
    return _toChart(p, [
      for (final r in rows) _ChartItem(_upper(r['label']! as String), r['amount']! as int, _id(r['c_sid'], r['c_lid'])),
    ]);
  }

  /// Dentro de las categorías elegidas, Σ por concepto ("CATEGORÍA : CONCEPTO" si son varias).
  Future<Map<String, dynamic>> byConceptInCategories(Map<String, dynamic> params) async {
    final p = _period(params);
    final cats = _ids(params['categoryIds']);
    if (cats.isEmpty) return _toChart(p, []);
    final (where, args) = _expenseWhere(p, _ids(params['accountIds']));
    final (catSql, catArgs) = _categoryFilter(cats);
    final rows = await _db.rawQuery('''
      SELECT MIN(d.concept) AS label, c.server_id AS c_sid, c.local_id AS c_lid, c.name AS category, SUM(-d.amount_cents) AS amount
      $_from
      WHERE $where AND $catSql AND d.concept IS NOT NULL AND TRIM(d.concept) <> ''
      GROUP BY c.local_id, d.concept
      ORDER BY COALESCE(c.server_id, 1000000000000 + c.local_id), d.concept''', [...args, ...catArgs]);
    final single = cats.length == 1;
    // Agrupa por etiqueta normalizada (sin mayúsculas ni acentos) y conserva la primera vista.
    final merged = <String, _ChartItem>{};
    for (final r in rows) {
      final label = single ? r['label']! as String : '${r['category']} : ${r['label']}';
      final key = _groupKey(label);
      final cur = merged[key];
      merged[key] = cur == null
          ? _ChartItem(_upper(label), r['amount']! as int, _id(r['c_sid'], r['c_lid']))
          : _ChartItem(cur.label, cur.amountCents + (r['amount']! as int), cur.categoryId);
    }
    return _toChart(p, merged.values.toList());
  }

  // ---------------- ingresos y egresos ----------------

  /// Ingresos vs egresos vs ahorro por mes y top 5 categorías del año.
  Future<Map<String, dynamic>> incomeExpense(Map<String, dynamic> params) async {
    final y = _int(params['year']) ?? DateTime.now().year;
    final years = await _years();
    final rows = await _db.rawQuery('''
      SELECT substr(h.occurred_at, 6, 2) AS month,
             SUM(CASE WHEN h.type = 1 THEN ABS(d.amount_cents) ELSE 0 END) AS income,
             SUM(CASE WHEN h.type = 2 THEN ABS(d.amount_cents) ELSE 0 END) AS expense
      FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
      WHERE $_inCurrency AND d.deleted = 0 AND h.deleted = 0 AND substr(h.occurred_at, 1, 4) = ?
      GROUP BY month ORDER BY month''', [currency, '$y']);
    final byMonth = {for (final r in rows) int.parse(r['month']! as String): r};
    final months = [
      for (var m = 1; m <= 12; m++)
        () {
          final income = byMonth[m]?['income'] as int? ?? 0;
          final expense = byMonth[m]?['expense'] as int? ?? 0;
          final balance = income - expense;
          return {
            'month': m,
            'incomeCents': income,
            'expenseCents': expense,
            'balanceCents': balance,
            'savingsRate': income > 0 ? _jsRound(balance / income * 10000) / 100 : 0,
          };
        }(),
    ];
    final income = months.fold<int>(0, (s, m) => s + (m['incomeCents']! as int));
    final expense = months.fold<int>(0, (s, m) => s + (m['expenseCents']! as int));
    final withExpense = months.where((m) => (m['expenseCents']! as int) > 0).toList();
    Map<String, dynamic>? pick(bool Function(int a, int b) better) {
      if (withExpense.isEmpty) return null;
      var best = withExpense.first;
      for (final m in withExpense.skip(1)) {
        if (better(m['expenseCents']! as int, best['expenseCents']! as int)) best = m;
      }
      return {'month': best['month'], 'amountCents': best['expenseCents']};
    }

    final top = await _db.rawQuery('''
      SELECT c.server_id AS c_sid, c.local_id AS c_lid, c.name, SUM(ABS(d.amount_cents)) AS amount
      $_from
      WHERE $_inCurrency AND d.deleted = 0 AND h.deleted = 0 AND h.type = 2 AND substr(h.occurred_at, 1, 4) = ?
      GROUP BY c.local_id ORDER BY amount DESC LIMIT 5''', [currency, '$y']);
    return {
      'year': y,
      'years': years,
      'months': months,
      'totals': {
        'incomeCents': income,
        'expenseCents': expense,
        'balanceCents': income - expense,
        'savingsRate': income > 0 ? _jsRound((income - expense) / income * 10000) / 100 : 0,
        'monthlyAverageExpenseCents': withExpense.isEmpty ? 0 : _jsRound(expense / withExpense.length),
        'highestExpenseMonth': pick((a, b) => a > b),
        'lowestExpenseMonth': pick((a, b) => a < b),
      },
      'topCategories': [
        for (final t in top)
          {
            'categoryId': _id(t['c_sid'], t['c_lid']),
            'name': t['name'],
            'amountCents': t['amount'],
            'percent': expense > 0 ? _jsRound((t['amount']! as int) / expense * 10000) / 100 : 0,
          },
      ],
    };
  }

  /// Ingresos y egresos por día de un mes.
  Future<Map<String, dynamic>> daily(Map<String, dynamic> params) async {
    final now = DateTime.now();
    final y = _int(params['year']) ?? now.year;
    final m = _int(params['month']) ?? now.month;
    final prefix = '$y-${'$m'.padLeft(2, '0')}';
    final rows = await _db.rawQuery('''
      SELECT substr(h.occurred_at, 9, 2) AS day,
             SUM(CASE WHEN h.type = 1 THEN ABS(d.amount_cents) ELSE 0 END) AS income,
             SUM(CASE WHEN h.type = 2 THEN ABS(d.amount_cents) ELSE 0 END) AS expense
      FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
      WHERE $_inCurrency AND d.deleted = 0 AND h.deleted = 0 AND substr(h.occurred_at, 1, 7) = ?
      GROUP BY day ORDER BY day''', [currency, prefix]);
    final byDay = {for (final r in rows) int.parse(r['day']! as String): r};
    return {
      'year': y,
      'month': m,
      'days': [
        for (var d = 1; d <= DateTime(y, m + 1, 0).day; d++)
          {
            'day': d,
            'date': '$prefix-${'$d'.padLeft(2, '0')}',
            'incomeCents': byDay[d]?['income'] as int? ?? 0,
            'expenseCents': byDay[d]?['expense'] as int? ?? 0,
          },
      ],
    };
  }

  // ---------------- productos ----------------

  /// Catálogo de productos: compras, primer/último/mínimo/máximo precio unitario.
  Future<List<Map<String, dynamic>>> products(Map<String, dynamic> params) async {
    final search = (params['search'] as String?)?.trim() ?? '';
    final limit = _int(params['limit']) ?? 50;
    final like = search.isEmpty ? null : '%${_escapeLike(search)}%';
    final rows = await _db.rawQuery('''
      SELECT d.concept, d.plu, COALESCE(NULLIF(d.unit_price_cents, 0), ABS(d.amount_cents)) AS unit, h.occurred_at, a.name AS account
      FROM movement_details d
      JOIN movement_headers h ON h.local_id = d.header_local_id
      JOIN accounts a ON a.local_id = d.account_local_id
      WHERE $_inCurrency AND d.deleted = 0 AND h.deleted = 0 AND h.type = 2 AND d.concept IS NOT NULL AND TRIM(d.concept) <> ''
        ${like == null ? '' : "AND (d.concept LIKE ? ESCAPE '\\' OR d.plu LIKE ? ESCAPE '\\')"}
      ORDER BY h.occurred_at, $_detailOrder''', [currency, if (like != null) ...[like, like]]);
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final key = _groupKey(r['concept']! as String);
      final unit = r['unit']! as int;
      final date = (r['occurred_at']! as String).substring(0, 10);
      final plu = (r['plu'] as String?)?.isEmpty ?? true ? null : r['plu'] as String;
      final cur = map[key];
      if (cur == null) {
        map[key] = {
          'concept': _upper(r['concept']! as String),
          'plu': plu,
          'purchases': 1,
          'firstDate': date,
          'lastDate': date,
          'firstPriceCents': unit,
          'lastPriceCents': unit,
          'minPriceCents': unit,
          'maxPriceCents': unit,
          'variationPercent': 0,
          'lastAccount': r['account'],
        };
      } else {
        cur['purchases'] = (cur['purchases'] as int) + 1;
        cur['lastDate'] = date;
        cur['lastPriceCents'] = unit;
        cur['lastAccount'] = r['account'];
        cur['plu'] ??= plu;
        if (unit < (cur['minPriceCents'] as int)) cur['minPriceCents'] = unit;
        if (unit > (cur['maxPriceCents'] as int)) cur['maxPriceCents'] = unit;
      }
    }
    final list = [
      for (final p in map.values)
        {
          ...p,
          'variationPercent': (p['firstPriceCents'] as int) > 0
              ? _jsRound(((p['lastPriceCents'] as int) - (p['firstPriceCents'] as int)) / (p['firstPriceCents'] as int) * 1000) / 10
              : 0,
        },
    ];
    _stableSort(list, (a, b) {
      final byPurchases = (b['purchases'] as int).compareTo(a['purchases'] as int);
      return byPurchases != 0 ? byPurchases : (b['lastDate'] as String).compareTo(a['lastDate'] as String);
    });
    return list.take(limit).toList();
  }

  /// Historial cronológico de precios de un producto (por concepto o PLU).
  Future<Map<String, dynamic>> productHistory(Map<String, dynamic> params) async {
    final concept = params['concept'] as String?;
    final plu = (params['plu'] as String?)?.isEmpty ?? true ? null : params['plu'] as String;
    final rows = await _db.rawQuery('''
      SELECT h.server_id AS h_sid, h.local_id AS h_lid, h.occurred_at, a.name AS account, c.name AS category, d.concept,
             COALESCE(NULLIF(d.unit_price_cents, 0), ABS(d.amount_cents)) AS unit, ABS(d.amount_cents) AS total
      FROM movement_details d
      JOIN movement_headers h ON h.local_id = d.header_local_id
      JOIN accounts a ON a.local_id = d.account_local_id
      LEFT JOIN categories c ON c.local_id = d.category_local_id
      WHERE $_inCurrency AND d.deleted = 0 AND h.deleted = 0 AND h.type = 2 AND ${plu != null ? 'd.plu = ?' : 'd.concept IS NOT NULL'}
      ORDER BY h.occurred_at, $_detailOrder''', [currency, if (plu != null) plu]);
    final filtered = plu != null ? rows : rows.where((r) => _groupKey((r['concept'] as String?) ?? '') == _groupKey(concept ?? '')).toList();
    final prices = [for (final r in filtered) r['unit']! as int];
    final first = prices.isEmpty ? 0 : prices.first;
    final last = prices.isEmpty ? 0 : prices.last;
    return {
      'concept': _upper(concept ?? (filtered.isEmpty ? null : filtered.first['concept'] as String?) ?? plu ?? ''),
      'purchases': filtered.length,
      'currentPriceCents': last,
      'initialPriceCents': first,
      'minPriceCents': prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b),
      'maxPriceCents': prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b),
      'increasePercent': first > 0 ? _jsRound((last - first) / first * 1000) / 10 : 0,
      'history': [
        for (final r in filtered)
          {
            'headerId': _id(r['h_sid'], r['h_lid']),
            'occurredAt': r['occurred_at'],
            'account': r['account'],
            'category': r['category'],
            'concept': r['concept'],
            'unitPriceCents': r['unit'],
            'totalCents': r['total'],
          },
      ],
    };
  }

  /// Último precio unitario por PLU en cada período e inflación entre ambos.
  Future<Map<String, dynamic>> compareProducts(Map<String, dynamic> params) async {
    final accounts = _ids(params['accountIds']);
    final cats = _ids(params['categoryIds']);
    Future<List<_PluPrice>> load(String from, String to) async {
      final (where, args) = _expenseWhere((from: from, to: to), accounts);
      final (catSql, catArgs) = cats.isEmpty ? ('1 = 1', const <Object?>[]) : _categoryFilter(cats);
      final rows = await _db.rawQuery('''
        SELECT d.plu, d.concept, d.unit_price_cents, d.server_id, d.local_id
        $_from
        WHERE $where AND $catSql AND d.plu IS NOT NULL AND d.plu <> ''
        ORDER BY d.plu''', [...args, ...catArgs]);
      // Por PLU: el renglón más nuevo (mayor id) da el precio; el concepto mayor (binario) da el nombre.
      final byPlu = <String, List<Map<String, Object?>>>{};
      for (final r in rows) {
        (byPlu[r['plu']! as String] ??= []).add(r);
      }
      int order(Map<String, Object?> r) => (r['server_id'] as int?) ?? 1000000000000 + (r['local_id']! as int);
      final out = [
        for (final e in byPlu.entries)
          () {
            final last = e.value.reduce((a, b) => order(a) >= order(b) ? a : b);
            final name = e.value.map((r) => r['concept'] as String?).whereType<String>().fold<String?>(
                null, (best, c) => best == null || c.compareTo(best) > 0 ? c : best);
            return _PluPrice(e.key, _asciiUpper((name ?? '').trim()), (last['unit_price_cents'] as int?) ?? 0, e.value.length);
          }(),
      ];
      _stableSort(out, (a, b) => a.name.compareTo(b.name));
      return out;
    }

    final p1 = await load(params['from1'] as String, params['to1'] as String);
    final p2 = await load(params['from2'] as String, params['to2'] as String);
    final map2 = {for (final p in p2) p.plu: p};
    final items = <Map<String, dynamic>>[];
    var sum = 0.0;
    var count = 0;
    for (final a in p1) {
      final b = map2[a.plu];
      if (b == null) continue;
      final diff = b.priceCents - a.priceCents;
      final pct = a.priceCents > 0 ? diff / a.priceCents * 100 : 0.0;
      items.add({
        'plu': a.plu,
        'name': b.name, // como el original: el nombre del período 2
        'price1Cents': a.priceCents,
        'price2Cents': b.priceCents,
        'quantity2': b.quantity,
        'differenceCents': diff,
        'percent': _round2(pct),
      });
      if (a.priceCents > 0) {
        sum += pct;
        count++;
      }
    }
    _stableSort(items, (a, b) => (b['differenceCents'] as int).compareTo(a['differenceCents'] as int));
    return {
      'items': items,
      'totals': {'commonProducts': items.length, 'averageInflation': count > 0 ? _round2(sum / count) : 0},
    };
  }

  // ---------------- ayudas ----------------

  static const _from = '''
    FROM movement_details d
    JOIN movement_headers h ON h.local_id = d.header_local_id
    JOIN categories c ON c.local_id = d.category_local_id
    JOIN accounts a ON a.local_id = d.account_local_id''';

  /// Orden de renglones de la API (`d.id`): lo que todavía no llegó al servidor va al final.
  static const _detailOrder = 'COALESCE(d.server_id, 1000000000000 + d.local_id)';

  /// Egresos de categorías activas en el período (y cuentas, si se eligieron).
  (String, List<Object?>) _expenseWhere(({String from, String to}) p, List<int> accountIds) {
    final conds = [_inCurrency, 'd.deleted = 0', 'h.deleted = 0', 'h.type = 2', 'c.active = 1', 'h.occurred_at >= ?', 'h.occurred_at <= ?'];
    final args = <Object?>[currency, '${p.from} 00:00:00', '${p.to} 23:59:59'];
    if (accountIds.isNotEmpty) {
      final (sql, a) = _idFilter('a', accountIds);
      conds.add(sql);
      args.addAll(a);
    }
    return (conds.join(' AND '), args);
  }

  static (String, List<Object?>) _categoryFilter(List<int> ids) => _idFilter('c', ids);

  /// Ids positivos = del servidor; negativos = locales (aún no enviados).
  static (String, List<Object?>) _idFilter(String alias, List<int> ids) {
    final server = ids.where((i) => i > 0).toList();
    final local = ids.where((i) => i < 0).map((i) => -i).toList();
    final parts = [
      if (server.isNotEmpty) '$alias.server_id IN (${List.filled(server.length, '?').join(',')})',
      if (local.isNotEmpty) '$alias.local_id IN (${List.filled(local.length, '?').join(',')})',
    ];
    return (parts.isEmpty ? '1 = 0' : '(${parts.join(' OR ')})', [...server, ...local]);
  }

  /// Período por defecto: el mes actual completo.
  static ({String from, String to}) _period(Map<String, dynamic> params) {
    final now = DateTime.now();
    String two(int v) => '$v'.padLeft(2, '0');
    final from = params['from'] as String? ?? '${now.year}-${two(now.month)}-01';
    final to = params['to'] as String? ?? '${now.year}-${two(now.month)}-${two(DateTime(now.year, now.month + 1, 0).day)}';
    return (from: from, to: to);
  }

  static Map<String, dynamic> _toChart(({String from, String to}) p, List<_ChartItem> items) {
    _stableSort(items, (a, b) => a.amountCents.compareTo(b.amountCents));
    return {
      'from': p.from,
      'to': p.to,
      'totalCents': items.fold<int>(0, (s, i) => s + i.amountCents),
      'items': [for (final i in items) {'label': i.label, 'amountCents': i.amountCents, 'categoryId': i.categoryId}],
    };
  }

  Future<List<int>> _years() async => [
        for (final r in await _db.rawQuery('''
          SELECT DISTINCT substr(occurred_at, 1, 4) AS y FROM movement_headers
          WHERE deleted = 0 AND substr(occurred_at, 1, 4) > '2000'
            AND EXISTS (SELECT 1 FROM movement_details d WHERE d.header_local_id = movement_headers.local_id AND d.deleted = 0 AND $_inCurrency)
          ORDER BY y DESC''', [currency]))
          int.parse(r['y']! as String),
      ];

  static int? _id(Object? serverId, Object? localId) => serverId as int? ?? (localId == null ? null : -(localId as int));

  static List<int> _ids(Object? csv) => csv is String && csv.isNotEmpty ? csv.split(',').map(int.parse).toList() : const [];

  static int? _int(Object? v) => v is int ? v : (v is String ? int.tryParse(v) : null);

  static String _escapeLike(String s) => s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  /// `Math.round` de JavaScript (redondea .5 hacia arriba, también en negativos).
  static int _jsRound(num x) => (x + 0.5).floor();
  static double _round2(num x) => _jsRound(x * 100) / 100;

  static String _upper(String s) => s.trim().toUpperCase();

  /// Mayúsculas solo de a-z (como UPPER de SQLite en el servidor).
  static String _asciiUpper(String s) =>
      String.fromCharCodes(s.codeUnits.map((c) => c >= 0x61 && c <= 0x7a ? c - 0x20 : c));

  /// Clave de agrupación sin mayúsculas ni acentos (como el servidor).
  static String _groupKey(String s) {
    const from = 'ÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇáàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'AAAAAEEEEIIIIOOOOOUUUUNCaaaaaeeeeiiiiooooouuuunc';
    final buf = StringBuffer();
    for (final ch in s.trim().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString().toUpperCase();
  }

  /// Orden estable (como Array.sort de JavaScript), para empates iguales a los del servidor.
  static void _stableSort<T>(List<T> list, int Function(T a, T b) compare) {
    final indexed = [for (final (i, e) in list.indexed) (i, e)];
    indexed.sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    for (final (i, e) in indexed.indexed) {
      list[i] = e.$2;
    }
  }
}

class _ChartItem {
  final String label;
  final int amountCents;
  final int? categoryId;
  const _ChartItem(this.label, this.amountCents, this.categoryId);
}

class _PluPrice {
  final String plu;
  final String name;
  final int priceCents;
  final int quantity;
  const _PluPrice(this.plu, this.name, this.priceCents, this.quantity);
}
