import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../errors/exceptions.dart';
import '../money/money.dart';
import '../network/dio_client.dart';

/// Diferencia entre la base local y el servidor en una cuenta.
class AccountMismatch {
  final int serverId;
  final String name;
  final int serverBalanceCents;
  final int localBalanceCents;
  final int serverCount;
  final int localCount;
  const AccountMismatch(this.serverId, this.name, this.serverBalanceCents, this.localBalanceCents, this.serverCount, this.localCount);

  @override
  String toString() => '$name (#$serverId): saldo servidor $serverBalanceCents vs local $localBalanceCents; '
      'renglones servidor $serverCount vs local $localCount';
}

class PullResult {
  final bool full;
  final int pages;
  final int movementsApplied;
  final int deletedApplied;

  /// Vacío = la base local coincide con el servidor (saldo y cantidad de renglones por cuenta).
  final List<AccountMismatch> mismatches;
  const PullResult({required this.full, required this.pages, required this.movementsApplied, required this.deletedApplied, required this.mismatches});

  bool get complete => mismatches.isEmpty;
}

/// Descarga del servidor (GET /sync/pull) a la base local, según docs/sync.md:
/// - sin cursor = descarga completa; con cursor = cambios desde la ventana anterior;
/// - repetir mientras `hasMore`; guardar el cursor solo al terminar;
/// - upsert por id (puede llegar el mismo registro más de una vez);
/// - aplicar `deleted` (en la descarga completa, borrar lo que el servidor ya no tiene).
/// Al final compara saldo y cantidad de renglones por cuenta con el servidor: si no
/// coinciden, no guarda el cursor (el próximo pull es completo) e informa la diferencia.
class PullService {
  final Database _db;
  final DioClient _client;
  final int pageSize;

  static Future<PullResult>? _inFlight;

  PullService(this._db, this._client, {this.pageSize = 500});

  /// Un solo pull a la vez: una llamada concurrente recibe el mismo resultado.
  Future<PullResult> pull() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<PullResult> _run() async {
    final state = (await _db.query('sync_state')).single;
    var cursor = state['cursor'] as String?;
    final full = cursor == null;
    final seen = _Seen();
    var pages = 0, movementsApplied = 0, deletedApplied = 0;
    List<Map<String, dynamic>> windowAccounts = const [];
    final total = Stopwatch()..start();
    final applying = Stopwatch();

    while (true) {
      final page = _map(
        await _client.get('/sync/pull', queryParameters: {if (cursor != null) 'cursor': cursor, 'limit': pageSize}),
        'pull',
      );
      pages++;
      final accounts = _list(page['accounts']).cast<Map<String, dynamic>>();
      if (accounts.isNotEmpty) windowAccounts = accounts; // la primera página trae todas las cuentas
      applying.start();
      await _db.transaction((txn) async {
        for (final a in accounts) {
          await _upsertAccount(txn, a);
          seen.accounts.add(a['id'] as int);
        }
        for (final c in _list(page['categories']).cast<Map<String, dynamic>>()) {
          await _upsertCategory(txn, c);
          seen.categories.add(c['id'] as int);
        }
        for (final b in _list(page['budgets']).cast<Map<String, dynamic>>()) {
          await _upsertBudget(txn, b);
          seen.budgets.add(b['id'] as int);
        }
        final movements = _list(page['movements']).cast<Map<String, dynamic>>();
        await upsertMovements(txn, movements);
        seen.headers.addAll(movements.map((m) => m['id'] as int));
        movementsApplied += movements.length;
        for (final d in _list(page['deleted']).cast<Map<String, dynamic>>()) {
          deletedApplied += await _applyDeleted(txn, d['entity'] as String, d['id'] as int);
        }
      });
      applying.stop();
      cursor = page['cursor'] as String?;
      if (page['hasMore'] != true) break;
    }

    if (full) deletedApplied += await _removeNotSeen(seen);

    final mismatches = await _verify(windowAccounts);
    debugPrint('[SYNC] Pull ${full ? 'completo' : 'incremental'}: $pages página(s), $movementsApplied comprobantes, '
        '${total.elapsedMilliseconds} ms (aplicar en SQLite: ${applying.elapsedMilliseconds} ms)');
    final now = DateTime.now().toUtc().toIso8601String();
    if (mismatches.isEmpty) {
      await _db.update('sync_state', {'cursor': cursor, 'last_pull_at': now}, where: 'id = 1');
    } else {
      // No coincide: se descarta el cursor para que el próximo pull sea completo.
      await _db.update('sync_state', {'cursor': null}, where: 'id = 1');
      debugPrint('[SYNC] Pull con diferencias: ${mismatches.join(' | ')}');
    }
    return PullResult(full: full, pages: pages, movementsApplied: movementsApplied, deletedApplied: deletedApplied, mismatches: mismatches);
  }

  // ---------------- upserts ----------------

  /// Busca por server_id y, si no está, por client_id (alta hecha en el celular). Devuelve local_id.
  Future<int?> _find(Transaction txn, String table, int serverId, Object? clientId) async {
    var rows = await txn.query(table, columns: ['local_id'], where: 'server_id = ?', whereArgs: [serverId]);
    if (rows.isEmpty && clientId is String) {
      rows = await txn.query(table, columns: ['local_id'], where: 'client_id = ?', whereArgs: [clientId]);
    }
    return rows.isEmpty ? null : rows.first['local_id'] as int;
  }

  static Map<String, Object?> _row(Map<String, dynamic> dto, Map<String, Object?> values) => {
        'server_id': dto['id'] as int,
        if (dto['clientId'] != null) 'client_id': dto['clientId'],
        'version': dto['version'],
        'deleted': 0,
        'deleted_at': null,
        'updated_at': dto['updatedAt'] ?? DateTime.now().toUtc().toIso8601String(),
        ...values,
      };

  Future<int> _upsert(Transaction txn, String table, Map<String, dynamic> dto, Map<String, Object?> values) async {
    final row = _row(dto, values);
    final localId = await _find(txn, table, dto['id'] as int, dto['clientId']);
    if (localId == null) return txn.insert(table, row);
    await txn.update(table, row, where: 'local_id = ?', whereArgs: [localId]);
    return localId;
  }

  Future<void> _upsertAccount(Transaction txn, Map<String, dynamic> a) => _upsert(txn, 'accounts', a, {
        'name': a['name'],
        'currency': Currency.parse(a['currency']).code,
        'active': a['active'] == true ? 1 : 0,
        'icon_ref': a['iconRef'],
        'image_url': a['imageUrl'],
        'created_by_user_id': a['createdByUserId'],
      });

  Future<void> _upsertCategory(Transaction txn, Map<String, dynamic> c) => _upsert(txn, 'categories', c, {
        'name': c['name'],
        'active': c['active'] == true ? 1 : 0,
        'role': c['role'],
        'created_by_user_id': c['createdByUserId'],
      });

  Future<void> _upsertBudget(Transaction txn, Map<String, dynamic> b) async {
    final localId = await _upsert(txn, 'budgets', b, {
      'start_date': b['startDate'],
      'end_date': b['endDate'],
      'limit_cents': Money.centsFrom(b['limitCents'], 'budget.limitCents'),
    });
    await txn.delete('budget_categories', where: 'budget_local_id = ?', whereArgs: [localId]);
    await txn.delete('budget_accounts', where: 'budget_local_id = ?', whereArgs: [localId]);
    for (final c in _list(b['categories']).cast<Map<String, dynamic>>()) {
      await txn.insert('budget_categories', {'budget_local_id': localId, 'category_local_id': await _require(txn, 'categories', c['id'] as int)});
    }
    for (final a in _list(b['accounts']).cast<Map<String, dynamic>>()) {
      await txn.insert('budget_accounts', {'budget_local_id': localId, 'account_local_id': await _require(txn, 'accounts', a['id'] as int)});
    }
  }

  /// Aplica un comprobante completo del servidor (MovementDto + id/version/clientId/updatedAt).
  /// También lo usa el push para aplicar el `current` de un conflicto (gana el servidor).
  Future<void> upsertMovement(Transaction txn, Map<String, dynamic> m) => upsertMovements(txn, [m]);

  /// Aplica comprobantes completos con pocas llamadas a SQLite (lecturas en bloque y `batch`):
  /// en Android cada consulta cruza el canal de plataforma, y una por renglón tardaba ~10 s por página.
  Future<void> upsertMovements(Transaction txn, List<Map<String, dynamic>> input) async {
    if (input.isEmpty) return;
    // El mismo comprobante puede llegar dos veces: vale el último.
    final movements = {for (final m in input) m['id'] as int: m}.values.toList();
    for (final m in movements) {
      if (m['partialDetails'] == true) throw _bad('movimiento ${m['id']} con renglones parciales');
    }
    final accounts = await _serverToLocal(txn, 'accounts');
    final categories = await _serverToLocal(txn, 'categories');
    int need(Map<Object?, int> ids, String table, int serverId) =>
        ids[serverId] ?? (throw _bad('$table #$serverId referenciada pero no recibida'));

    // Encabezados: por server_id y, si no está, por client_id (alta hecha en el celular).
    final byServer = await _localIdsIn(txn, 'movement_headers', 'server_id', [for (final m in movements) m['id']]);
    final byClient = await _localIdsIn(txn, 'movement_headers', 'client_id', [
      for (final m in movements)
        if (m['clientId'] is String) m['clientId'],
    ]);
    final existing = [for (final m in movements) byServer[m['id']] ?? byClient[m['clientId']]];
    final headers = txn.batch();
    for (final (i, m) in movements.indexed) {
      final row = _row(m, {
        'type': m['type'],
        'occurred_at': m['occurredAt'],
        'general_concept': m['generalConcept'],
        'created_by_user_id': m['createdByUserId'],
        'created_by_name': m['createdByName'],
      });
      final localId = existing[i];
      if (localId == null) {
        headers.insert('movement_headers', row);
      } else {
        headers.update('movement_headers', row, where: 'local_id = ?', whereArgs: [localId]);
      }
    }
    final inserted = await headers.commit();
    final headerIds = [for (final (i, localId) in existing.indexed) localId ?? inserted[i] as int];

    final details = [for (final m in movements) _list(m['details']).cast<Map<String, dynamic>>()];
    final existingDetails = await _localIdsIn(txn, 'movement_details', 'server_id', [
      for (final ds in details)
        for (final d in ds) d['id'],
    ]);
    final batch = txn.batch();
    for (final (i, m) in movements.indexed) {
      final updatedAt = m['updatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String();
      for (final d in details[i]) {
        final serverId = d['id'] as int;
        final categoryId = d['categoryId'] as int?;
        final unit = d['unitPriceCents'];
        final values = {
          'server_id': serverId,
          'header_local_id': headerIds[i],
          'account_local_id': need(accounts, 'accounts', d['accountId'] as int),
          'category_local_id': categoryId == null ? null : need(categories, 'categories', categoryId),
          'concept': d['concept'],
          'amount_cents': Money.centsFrom(d['amountCents'], 'detail.amountCents'),
          'plu': d['plu'],
          'unit_price_cents': unit == null ? null : Money.centsFrom(unit, 'detail.unitPriceCents'),
          'image_url': d['imageUrl'],
          'deleted': 0,
          'deleted_at': null,
          'updated_at': updatedAt,
        };
        final localId = existingDetails[serverId];
        if (localId == null) {
          batch.insert('movement_details', values);
        } else {
          batch.update('movement_details', values, where: 'local_id = ?', whereArgs: [localId]);
        }
      }
    }
    // Los borrados van después de todas las altas y cambios: un renglón que pasó a otro
    // comprobante de la misma página ya no está en el anterior cuando se borra lo que sobra.
    for (final (i, headerId) in headerIds.indexed) {
      final keep = [for (final d in details[i]) d['id'] as int];
      // Si el comprobante se cargó en el celular (encontrado por clientId), el servidor ya lo
      // registró: sus renglones reemplazan a los locales sin server_id (no se duplican).
      batch.delete('movement_details', where: 'header_local_id = ? AND server_id IS NULL', whereArgs: [headerId]);
      // El servidor manda el comprobante completo: los renglones del servidor que ya no vienen se borraron.
      batch.delete(
        'movement_details',
        where: 'header_local_id = ? AND server_id IS NOT NULL'
            '${keep.isEmpty ? '' : ' AND server_id NOT IN (${List.filled(keep.length, '?').join(',')})'}',
        whereArgs: [headerId, ...keep],
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<Map<Object?, int>> _serverToLocal(Transaction txn, String table) async => {
        for (final r in await txn.query(table, columns: ['server_id', 'local_id'], where: 'server_id IS NOT NULL'))
          r['server_id']: r['local_id'] as int,
      };

  /// local_id de las filas cuyo `column` está en `values`, en tandas (límite de parámetros de SQLite).
  static Future<Map<Object?, int>> _localIdsIn(Transaction txn, String table, String column, List<Object?> values) async {
    final out = <Object?, int>{};
    for (var i = 0; i < values.length; i += 500) {
      final chunk = values.sublist(i, i + 500 > values.length ? values.length : i + 500);
      final rows = await txn.query(table,
          columns: [column, 'local_id'], where: '$column IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: chunk);
      for (final r in rows) {
        out[r[column]] = r['local_id'] as int;
      }
    }
    return out;
  }

  /// Local id de una entidad referenciada por el servidor; si no está, la base quedaría inconsistente.
  Future<int> _require(Transaction txn, String table, int serverId) async {
    final rows = await txn.query(table, columns: ['local_id'], where: 'server_id = ?', whereArgs: [serverId]);
    if (rows.isEmpty) throw _bad('$table #$serverId referenciada pero no recibida');
    return rows.first['local_id'] as int;
  }

  // ---------------- eliminados ----------------

  static const _tables = {
    'account': 'accounts',
    'category': 'categories',
    'budget': 'budgets',
    'movement_header': 'movement_headers',
    'movement_detail': 'movement_details',
  };

  Future<int> _applyDeleted(Transaction txn, String entity, int serverId) async {
    final table = _tables[entity];
    if (table == null) throw _bad('entidad eliminada desconocida: $entity');
    // El servidor borra los vínculos con límites junto con la cuenta/categoría, sin tombstone propio.
    await _unlinkFromBudgets(txn, table, 'server_id = ?', [serverId]);
    // Borrado físico: el servidor ya lo eliminó (los renglones de un encabezado caen en cascada).
    return txn.delete(table, where: 'server_id = ?', whereArgs: [serverId]);
  }

  static Future<void> _unlinkFromBudgets(Transaction txn, String table, String where, List<Object?> args) async {
    final link = switch (table) {
      'accounts' => ('budget_accounts', 'account_local_id'),
      'categories' => ('budget_categories', 'category_local_id'),
      _ => null,
    };
    if (link == null) return;
    await txn.delete(link.$1, where: '${link.$2} IN (SELECT local_id FROM $table WHERE $where)', whereArgs: args);
  }

  /// Descarga completa: lo que vino del servidor y ya no está, se borró allá.
  Future<int> _removeNotSeen(_Seen seen) => _db.transaction((txn) async {
        Future<int> prune(String table, Set<int> ids) async {
          final where = 'server_id IS NOT NULL${ids.isEmpty ? '' : ' AND server_id NOT IN (${ids.join(',')})'}';
          await _unlinkFromBudgets(txn, table, where, const []);
          return txn.delete(table, where: where);
        }
        var n = await prune('movement_headers', seen.headers);
        n += await prune('budgets', seen.budgets);
        n += await prune('categories', seen.categories);
        n += await prune('accounts', seen.accounts);
        return n;
      });

  // ---------------- verificación ----------------

  /// Saldo y cantidad de renglones por cuenta: base local contra lo que informó el servidor.
  /// Solo cuenta comprobantes que el servidor ya tiene (con server_id): lo cargado en el
  /// celular y pendiente de enviar todavía no existe allá. Un comprobante recién aplicado por
  /// el push ya tiene server_id aunque sus renglones reciban el suyo en un pull posterior.
  Future<List<AccountMismatch>> _verify(List<Map<String, dynamic>> serverAccounts) async {
    const synced = 'd.deleted = 0 AND h.deleted = 0 AND h.server_id IS NOT NULL';
    final local = {
      for (final r in await _db.rawQuery('''
        SELECT a.server_id AS id,
               COALESCE(SUM(CASE WHEN $synced THEN d.amount_cents END), 0) AS balance,
               COUNT(CASE WHEN $synced THEN d.local_id END) AS n
        FROM accounts a
        LEFT JOIN movement_details d ON d.account_local_id = a.local_id
        LEFT JOIN movement_headers h ON h.local_id = d.header_local_id
        WHERE a.server_id IS NOT NULL AND a.deleted = 0
        GROUP BY a.local_id'''))
        r['id'] as int: (r['balance'] as int, r['n'] as int),
    };
    final out = <AccountMismatch>[];
    for (final a in serverAccounts) {
      final id = a['id'] as int;
      final serverBalance = Money.centsFrom(a['balanceCents'], 'account.balanceCents');
      final serverCount = a['movementsCount'] as int;
      final (lb, ln) = local[id] ?? (0, 0);
      if (lb != serverBalance || ln != serverCount) {
        out.add(AccountMismatch(id, a['name'] as String? ?? '', serverBalance, lb, serverCount, ln));
      }
    }
    if (serverAccounts.length != local.length) {
      out.add(AccountMismatch(0, 'cantidad de cuentas', serverAccounts.length, local.length, 0, 0));
    }
    return out;
  }

  static Map<String, dynamic> _map(Object? v, String f) => v is Map<String, dynamic> ? v : throw _bad(f);
  static List<dynamic> _list(Object? v) => v is List ? v : const [];
  static ServerException _bad(String what) => ServerException('Sincronización: $what', null, 'UNEXPECTED_RESPONSE');
}

class _Seen {
  final accounts = <int>{};
  final categories = <int>{};
  final budgets = <int>{};
  final headers = <int>{};
}
