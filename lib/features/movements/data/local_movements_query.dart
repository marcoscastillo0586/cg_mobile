import 'package:sqflite/sqflite.dart';
import 'movements_repository.dart';

/// `GET /movements` sobre la base del celular (historial sin conexión): mismas reglas que
/// movements-query.service.ts y la misma forma de respuesta, para usar el mismo parser.
///
/// Ids: los del servidor; lo que todavía no llegó al servidor usa el id local en negativo.
/// Los filtros por cuenta y categoría reciben ids del servidor, como la API.
class LocalMovementsQuery {
  final DatabaseExecutor _db;
  LocalMovementsQuery(this._db);

  /// Sin rango de fechas la API devuelve 60 (MOVEMENTS_DEFAULT_LIMIT); con rango, de a 100.
  static const _defaultLimit = 60;
  static const _rangePageSize = 100;

  Future<Map<String, dynamic>> list(MovementsQuery q) async {
    final hasRange = (q.from?.isNotEmpty ?? false) || (q.to?.isNotEmpty ?? false);
    final limit = q.limit > 0 ? q.limit : (hasRange ? _rangePageSize : _defaultLimit);
    final text = q.q?.trim() ?? '';
    final search = text.isEmpty ? null : _Search.parse(text);

    final where = <String>['h.deleted = 0', 'd.deleted = 0', 'a.active = 1'];
    final args = <Object?>[];
    if (q.from?.isNotEmpty ?? false) {
      where.add('h.occurred_at >= ?');
      args.add('${q.from} 00:00:00');
    }
    if (q.to?.isNotEmpty ?? false) {
      where.add('h.occurred_at <= ?');
      args.add('${q.to} 23:59:59');
    }
    if (q.categoryIds.isNotEmpty) {
      where.add('d.category_local_id IN (SELECT local_id FROM categories WHERE server_id IN (${_marks(q.categoryIds)}))');
      args.addAll(q.categoryIds);
    }
    if (q.accountIds.isNotEmpty) {
      where.add('a.server_id IN (${_marks(q.accountIds)})');
      args.addAll(q.accountIds);
    }
    var conceptMatch = '0';
    final conceptArgs = <Object?>[];
    if (search != null) {
      conceptMatch = "(h.general_concept LIKE ? ESCAPE '\\')";
      conceptArgs.add(search.like);
      final (detailSql, detailArgs) = search.sql('d2');
      where.add('($conceptMatch OR EXISTS (SELECT 1 FROM movement_details d2 '
          'WHERE d2.header_local_id = h.local_id AND d2.deleted = 0 AND $detailSql))');
      args
        ..add(search.like)
        ..addAll(detailArgs);
    }
    const base = '''
      FROM movement_headers h
      JOIN movement_details d ON d.header_local_id = h.local_id
      JOIN accounts a ON a.local_id = d.account_local_id''';
    final whereSql = where.join(' AND ');
    // Orden de la API: fecha y, a igual fecha, id; lo no enviado (sin id del servidor) es lo más nuevo.
    const order = 'h.occurred_at DESC, COALESCE(h.server_id, 1000000000000 + h.local_id) DESC';

    final headers = await _db.rawQuery('''
      SELECT h.local_id, h.server_id, h.type, h.occurred_at, h.general_concept, h.created_by_user_id, h.created_by_name,
             SUM(d.amount_cents) AS sum_cents, MAX(ABS(d.amount_cents)) AS max_abs, MIN(a.name) AS first_account,
             (SELECT COUNT(*) FROM movement_details x WHERE x.header_local_id = h.local_id AND x.deleted = 0) AS details_total,
             $conceptMatch AS concept_match
      $base
      WHERE $whereSql
      GROUP BY h.local_id
      ORDER BY $order
      LIMIT ? OFFSET ?''', [...conceptArgs, ...args, limit, q.offset]);

    final agg = (await _db.rawQuery('''
      SELECT COUNT(*) AS total, SUM(amt) AS sum_all FROM (
        SELECT CASE WHEN h.type = 3 THEN MAX(ABS(d.amount_cents)) ELSE SUM(d.amount_cents) END AS amt
        $base WHERE $whereSql GROUP BY h.local_id
      )''', args)).first;

    final ids = [for (final h in headers) h['local_id']! as int];
    final details = ids.isEmpty ? const <Map<String, Object?>>[] : await _details(ids);
    final items = <Map<String, dynamic>>[];
    for (final h in headers) {
      var ds = details.where((d) => d['header_local_id'] == h['local_id']).toList();
      var partial = false;
      // Como la API: con filtro de categoría o cuenta solo se muestran los renglones que cumplen.
      if (q.categoryIds.isNotEmpty || q.accountIds.isNotEmpty) {
        final filtered = ds
            .where((d) =>
                (q.categoryIds.isEmpty || q.categoryIds.contains(d['c_sid'])) &&
                (q.accountIds.isEmpty || q.accountIds.contains(d['a_sid'])))
            .toList();
        partial = filtered.length != ds.length;
        ds = filtered;
      }
      if (search != null && (h['concept_match'] as int? ?? 0) == 0) {
        final matched = ds.where(search.matches).toList();
        partial = partial || matched.length != ds.length;
        ds = matched;
      }
      items.add(_toDto(h, ds, partial));
    }
    final total = agg['total'] as int? ?? 0;
    return {
      'items': items,
      'total': total,
      'limit': limit,
      'offset': q.offset,
      'hasMore': q.offset + items.length < total,
      'filteredTotalCents': ((agg['sum_all'] as int?) ?? 0).abs(),
    };
  }

  Future<List<Map<String, Object?>>> _details(List<int> headerIds) => _db.rawQuery('''
      SELECT d.local_id, d.server_id, d.header_local_id, a.local_id AS a_lid, a.server_id AS a_sid, a.name AS account_name,
             a.active AS account_active, a.currency, c.local_id AS c_lid, c.server_id AS c_sid, c.name AS category_name,
             c.role AS category_role, d.concept, d.amount_cents, d.plu, d.unit_price_cents, d.image_url
      FROM movement_details d
      JOIN accounts a ON a.local_id = d.account_local_id
      LEFT JOIN categories c ON c.local_id = d.category_local_id
      WHERE d.deleted = 0 AND d.header_local_id IN (${_marks(headerIds)})
      ORDER BY d.header_local_id, c.name DESC, d.local_id''', headerIds);

  static int? _id(Object? serverId, Object? localId) => serverId as int? ?? (localId == null ? null : -(localId as int));

  static Map<String, dynamic> _toDto(Map<String, Object?> h, List<Map<String, Object?>> ds, bool partial) {
    final type = h['type']! as int;
    final details = [
      for (final d in ds)
        {
          'id': _id(d['server_id'], d['local_id']),
          'accountId': _id(d['a_sid'], d['a_lid']),
          'accountName': d['account_name'],
          'accountActive': d['account_active'] == 1,
          'currency': d['currency'],
          'categoryId': _id(d['c_sid'], d['c_lid']),
          'categoryName': d['category_name'],
          'categoryRole': d['category_role'],
          'concept': d['concept'],
          'observation': null,
          'amountCents': d['amount_cents'],
          'plu': d['plu'],
          'unitPriceCents': d['unit_price_cents'],
          'imageUrl': d['image_url'],
          'imageNote': null,
        },
    ];
    final from = type == 3 ? details.where((d) => (d['amountCents']! as int) < 0).firstOrNull : null;
    final to = type == 3 ? details.where((d) => (d['amountCents']! as int) > 0).firstOrNull : null;
    final names = <String>{
      ...(type == 3 ? [from?['accountName'], to?['accountName']] : details.map((d) => d['accountName'])).whereType<String>(),
    }.toList();
    return {
      'id': _id(h['server_id'], h['local_id']),
      'type': type,
      'occurredAt': h['occurred_at'],
      'generalConcept': h['general_concept'],
      'accountNames': names.isNotEmpty ? names : [h['first_account']].whereType<String>().toList(),
      'amountCents': type == 3 ? h['max_abs'] : h['sum_cents'],
      'detailsCount': h['details_total'],
      'partialDetails': partial,
      'details': details,
      'fromAccountId': from?['accountId'],
      'toAccountId': to?['accountId'],
      'createdByUserId': h['created_by_user_id'],
      'createdByName': h['created_by_name'],
    };
  }

  static String _marks(List<Object?> v) => List.filled(v.length, '?').join(',');
}

/// Búsqueda como texto o monto (`parseSearch` de la API).
class _Search {
  final String like;
  final int? exactCents;
  final int? intPesos;
  const _Search(this.like, {this.exactCents, this.intPesos});

  static _Search parse(String q) {
    final like = '%${q.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    final cleaned = q.replaceAll(RegExp(r'[$\s]'), '');
    final normalized = cleaned.contains(',') ? cleaned.replaceAll('.', '').replaceFirst(',', '.') : cleaned;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return _Search(like);
    final hasDecimals = cleaned.contains(',') || RegExp(r'\.\d{1,2}$').hasMatch(cleaned);
    if (hasDecimals) return _Search(like, exactCents: (double.parse(normalized) * 100).round());
    return _Search(like, intPesos: int.parse(normalized));
  }

  (String, List<Object?>) sql(String alias) {
    final conds = ["$alias.concept LIKE ? ESCAPE '\\'"];
    final args = <Object?>[like];
    if (exactCents != null) {
      conds.add('ABS($alias.amount_cents) = ?');
      args.add(exactCents);
    }
    if (intPesos != null) {
      conds.add('ABS($alias.amount_cents) BETWEEN ? AND ?');
      args.addAll([intPesos! * 100, intPesos! * 100 + 99]);
    }
    return ('(${conds.join(' OR ')})', args);
  }

  bool matches(Map<String, Object?> d) {
    final needle = like.substring(1, like.length - 1).replaceAllMapped(RegExp(r'\\([\\%_])'), (m) => m[1]!).toLowerCase();
    final abs = (d['amount_cents']! as int).abs();
    if (((d['concept'] as String?) ?? '').toLowerCase().contains(needle)) return true;
    if (exactCents != null && abs == exactCents) return true;
    if (intPesos != null && abs ~/ 100 == intPesos) return true;
    return false;
  }
}
