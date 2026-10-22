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

    while (true) {
      final page = _map(
        await _client.get('/sync/pull', queryParameters: {if (cursor != null) 'cursor': cursor, 'limit': pageSize}),
        'pull',
      );
      pages++;
      final accounts = _list(page['accounts']).cast<Map<String, dynamic>>();
      if (accounts.isNotEmpty) windowAccounts = accounts; // la primera página trae todas las cuentas
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
        for (final m in _list(page['movements']).cast<Map<String, dynamic>>()) {
          await _upsertMovement(txn, m);
          seen.headers.add(m['id'] as int);
          movementsApplied++;
        }
        for (final d in _list(page['deleted']).cast<Map<String, dynamic>>()) {
          deletedApplied += await _applyDeleted(txn, d['entity'] as String, d['id'] as int);
        }
      });
      cursor = page['cursor'] as String?;
      if (page['hasMore'] != true) break;
    }

    if (full) deletedApplied += await _removeNotSeen(seen);

    final mismatches = await _verify(windowAccounts);
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

  Future<int> _upsert(Transaction txn, String table, Map<String, dynamic> dto, Map<String, Object?> values) async {
    final serverId = dto['id'] as int;
    final row = {
      'server_id': serverId,
      if (dto['clientId'] != null) 'client_id': dto['clientId'],
      'version': dto['version'],
      'deleted': 0,
      'deleted_at': null,
      'updated_at': dto['updatedAt'] ?? DateTime.now().toUtc().toIso8601String(),
      ...values,
    };
    final localId = await _find(txn, table, serverId, dto['clientId']);
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
      });

  Future<void> _upsertCategory(Transaction txn, Map<String, dynamic> c) => _upsert(txn, 'categories', c, {
        'name': c['name'],
        'active': c['active'] == true ? 1 : 0,
        'role': c['role'],
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

  Future<void> _upsertMovement(Transaction txn, Map<String, dynamic> m) async {
    if (m['partialDetails'] == true) throw _bad('movimiento ${m['id']} con renglones parciales');
    final updatedAt = m['updatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String();
    final headerId = await _upsert(txn, 'movement_headers', m, {
      'type': m['type'],
      'occurred_at': m['occurredAt'],
      'general_concept': m['generalConcept'],
    });
    final keep = <int>[];
    for (final d in _list(m['details']).cast<Map<String, dynamic>>()) {
      final serverId = d['id'] as int;
      keep.add(serverId);
      final categoryId = d['categoryId'] as int?;
      final unit = d['unitPriceCents'];
      final values = {
        'server_id': serverId,
        'header_local_id': headerId,
        'account_local_id': await _require(txn, 'accounts', d['accountId'] as int),
        'category_local_id': categoryId == null ? null : await _require(txn, 'categories', categoryId),
        'concept': d['concept'],
        'amount_cents': Money.centsFrom(d['amountCents'], 'detail.amountCents'),
        'plu': d['plu'],
        'unit_price_cents': unit == null ? null : Money.centsFrom(unit, 'detail.unitPriceCents'),
        'image_url': d['imageUrl'],
        'deleted': 0,
        'deleted_at': null,
        'updated_at': updatedAt,
      };
      final existing = await txn.query('movement_details', columns: ['local_id'], where: 'server_id = ?', whereArgs: [serverId]);
      if (existing.isEmpty) {
        await txn.insert('movement_details', values);
      } else {
        await txn.update('movement_details', values, where: 'local_id = ?', whereArgs: [existing.first['local_id']]);
      }
    }
    // El servidor manda el comprobante completo: los renglones del servidor que ya no vienen se borraron.
    await txn.delete(
      'movement_details',
      where: 'header_local_id = ? AND server_id IS NOT NULL'
          '${keep.isEmpty ? '' : ' AND server_id NOT IN (${List.filled(keep.length, '?').join(',')})'}',
      whereArgs: [headerId, ...keep],
    );
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

  Future<int> _applyDeleted(Transaction txn, String entity, int serverId) {
    final table = _tables[entity];
    if (table == null) throw _bad('entidad eliminada desconocida: $entity');
    // Borrado físico: el servidor ya lo eliminó (los renglones de un encabezado caen en cascada).
    return txn.delete(table, where: 'server_id = ?', whereArgs: [serverId]);
  }

  /// Descarga completa: lo que vino del servidor y ya no está, se borró allá.
  Future<int> _removeNotSeen(_Seen seen) => _db.transaction((txn) async {
        Future<int> prune(String table, Set<int> ids) => txn.delete(
              table,
              where: 'server_id IS NOT NULL${ids.isEmpty ? '' : ' AND server_id NOT IN (${ids.join(',')})'}',
            );
        var n = await prune('movement_headers', seen.headers);
        n += await prune('budgets', seen.budgets);
        n += await prune('categories', seen.categories);
        n += await prune('accounts', seen.accounts);
        return n;
      });

  // ---------------- verificación ----------------

  /// Saldo y cantidad de renglones por cuenta: base local contra lo que informó el servidor.
  Future<List<AccountMismatch>> _verify(List<Map<String, dynamic>> serverAccounts) async {
    final local = {
      for (final r in await _db.rawQuery('''
        SELECT a.server_id AS id,
               COALESCE(SUM(CASE WHEN d.deleted = 0 AND h.deleted = 0 THEN d.amount_cents END), 0) AS balance,
               COUNT(CASE WHEN d.deleted = 0 AND h.deleted = 0 THEN d.local_id END) AS n
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
