import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/local_ops.dart';
import '../../../core/sync/outbox.dart';
import '../domain/budget.dart';

/// Máximo de categorías por límite (BUDGET_MAX_CATEGORIES de @cg/shared).
const budgetMaxCategories = 5;

final localBudgetsRepositoryProvider = Provider<Future<LocalBudgetsRepository>>(
  (ref) async => LocalBudgetsRepository(await ref.watch(localDatabaseProvider)),
);

/// Límites de gasto desde la base local (consumo calculado acá, sin conexión) con alta,
/// edición (fechas y monto), renovación y baja por la outbox. Reglas de budgets.service.ts.
class LocalBudgetsRepository {
  final Database _db;
  final DateTime Function() _now;
  LocalBudgetsRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Orden del servidor: monto límite descendente, luego id.
  Future<List<Budget>> list() async {
    final rows = await _db.query('budgets', where: 'deleted = 0');
    final out = [for (final r in rows) await _budget(r)];
    out.sort((a, b) {
      final byLimit = b.limitCents.compareTo(a.limitCents);
      if (byLimit != 0) return byLimit;
      return (a.serverId ?? 1 << 40).compareTo(b.serverId ?? 1 << 40);
    });
    return out;
  }

  Future<Budget> _budget(Map<String, Object?> r) async {
    final id = r['local_id']! as int;
    final cats = (await _db.rawQuery('''
        SELECT c.local_id, c.name FROM budget_categories bc JOIN categories c ON c.local_id = bc.category_local_id
        WHERE bc.budget_local_id = ? ORDER BY c.name COLLATE NOCASE''', [id])).map((c) => BudgetRef(c['local_id']! as int, c['name']! as String)).toList();
    final accs = (await _db.rawQuery('''
        SELECT a.local_id, a.name FROM budget_accounts ba JOIN accounts a ON a.local_id = ba.account_local_id
        WHERE ba.budget_local_id = ? ORDER BY a.name COLLATE NOCASE''', [id])).map((a) => BudgetRef(a['local_id']! as int, a['name']! as String)).toList();
    final start = r['start_date']! as String, end = r['end_date']! as String;
    final limit = r['limit_cents']! as int;
    final consumed = await consumption(_db, start, end, accs.map((a) => a.id).toList(), cats.map((c) => c.id).toList());
    return Budget(
      id: id,
      serverId: r['server_id'] as int?,
      startDate: start,
      endDate: end,
      limitCents: limit,
      consumedCents: consumed,
      percentHundredths: truncatedPercentHundredths(consumed, limit),
      dueForRenewal: LocalOps.todayAr(_now()).compareTo(end) >= 0,
      categories: cats,
      accounts: accs,
      version: r['version'] as int?,
    );
  }

  /// Consumo = Σ(−monto) de egresos (tipo 2) del período en las cuentas y categorías del límite,
  /// con el día "hasta" completo (decisión U3 del servidor). Incluye lo pendiente de enviar.
  static Future<int> consumption(DatabaseExecutor db, String start, String end, List<int> accountIds, List<int> categoryIds) async {
    if (accountIds.isEmpty || categoryIds.isEmpty) return 0;
    final row = (await db.rawQuery('''
        SELECT COALESCE(SUM(-d.amount_cents), 0) AS total
        FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
        WHERE h.type = 2 AND h.deleted = 0 AND d.deleted = 0
          AND h.occurred_at >= ? AND h.occurred_at <= ?
          AND d.account_local_id IN (${accountIds.join(',')})
          AND d.category_local_id IN (${categoryIds.join(',')})''', ['$start 00:00:00', '$end 23:59:59'])).first;
    return row['total']! as int;
  }

  /// Igual que `truncatedPercent` de @cg/shared pero en centésimos enteros (sin double).
  static int? truncatedPercentHundredths(int consumed, int limit) => limit == 0 ? null : (consumed * 10000) ~/ limit;

  Future<String> create({
    required String startDate,
    required String endDate,
    required int limitCents,
    required List<int> categoryIds,
    required List<int> accountIds,
  }) =>
      _db.transaction((txn) async {
        _period(startDate, endDate);
        if (limitCents <= 0) throw LocalOps.invalid('El monto debe ser mayor a cero');
        final cats = categoryIds.toSet().toList(), accs = accountIds.toSet().toList();
        if (cats.isEmpty) throw LocalOps.invalid('Seleccione al menos una categoría');
        if (cats.length > budgetMaxCategories) throw LocalOps.invalid('Máximo $budgetMaxCategories categorías');
        if (accs.isEmpty) throw LocalOps.invalid('Debe seleccionar al menos un lugar donde aplicar el límite de gastos');
        final catRefs = <Map<String, Object>>[];
        for (final id in cats) {
          final c = await LocalOps.require(txn, 'categories', id, 'La categoría');
          if (c['role'] == 'TRANSFER' || c['role'] == 'INCOME') {
            throw ValidationFailure('La categoría ${c['name']} no puede usarse en límites de gasto', null, 'RESERVED_CATEGORY');
          }
          catRefs.add(LocalOps.ref(c));
        }
        final accRefs = [for (final id in accs) LocalOps.ref(await LocalOps.require(txn, 'accounts', id, 'La cuenta'))];
        final clientId = LocalDatabase.newId();
        final localId = await txn.insert('budgets', {
          'client_id': clientId, 'start_date': startDate, 'end_date': endDate, 'limit_cents': limitCents, 'updated_at': LocalOps.stamp(),
        });
        for (final c in cats) {
          await txn.insert('budget_categories', {'budget_local_id': localId, 'category_local_id': c});
        }
        for (final a in accs) {
          await txn.insert('budget_accounts', {'budget_local_id': localId, 'account_local_id': a});
        }
        return Outbox.enqueue(txn, entity: 'budget', action: 'create', clientId: clientId, data: {
          'startDate': startDate,
          'endDate': endDate,
          'limit': Money.toApiDecimal(limitCents),
          'categoryRefs': catRefs,
          'accountRefs': accRefs,
        });
      });

  /// Fechas y/o monto (la API de sincronización no cambia categorías ni cuentas de un límite).
  Future<String> update(int localId, {String? startDate, String? endDate, int? limitCents}) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'budgets', localId, 'El límite');
        final changes = <String, Object?>{};
        final data = <String, Object?>{};
        if (startDate != null && startDate != row['start_date']) {
          changes['start_date'] = startDate;
          data['startDate'] = startDate;
        }
        if (endDate != null && endDate != row['end_date']) {
          changes['end_date'] = endDate;
          data['endDate'] = endDate;
        }
        if (limitCents != null && limitCents != row['limit_cents']) {
          if (limitCents <= 0) throw LocalOps.invalid('El monto debe ser mayor a cero');
          changes['limit_cents'] = limitCents;
          data['limit'] = Money.toApiDecimal(limitCents);
        }
        if (data.isEmpty) throw LocalOps.invalid('No hay cambios para guardar');
        _period((changes['start_date'] ?? row['start_date'])! as String, (changes['end_date'] ?? row['end_date'])! as String);
        return _enqueueUpdate(txn, row, changes, data);
      });

  /// `renovarLimiteGasto`: desde + 1 mes; hasta = último día del mes de (hasta + 1 mes).
  Future<String> renew(int localId) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'budgets', localId, 'El límite');
        return _enqueueUpdate(txn, row, {
          'start_date': addMonths(row['start_date']! as String, 1),
          'end_date': lastDayOfMonth(addMonths(row['end_date']! as String, 1)),
        }, {'renew': true});
      });

  Future<String?> delete(int localId) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'budgets', localId, 'El límite');
        return LocalOps.deleteRow(txn, entity: 'budget', table: 'budgets', row: row);
      });

  Future<String> _enqueueUpdate(Transaction txn, Map<String, Object?> row, Map<String, Object?> changes, Map<String, Object?> data) async {
    final localId = row['local_id']! as int;
    await txn.update('budgets', {...changes, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
    return Outbox.enqueue(txn,
        entity: 'budget',
        action: 'update',
        ref: LocalOps.ref(row),
        baseVersion: LocalOps.baseVersion(row),
        data: data,
        undo: {'table': 'budgets', 'local_id': localId, 'values': {for (final k in changes.keys) k: row[k]}});
  }

  static void _period(String start, String end) {
    final re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!re.hasMatch(start) || !re.hasMatch(end)) throw LocalOps.invalid('Fecha inválida');
    if (end.compareTo(start) < 0) {
      throw const ValidationFailure('La fecha hasta no puede ser anterior a la fecha desde', null, 'INVALID_PERIOD');
    }
  }

  // ---------------- fechas (semántica MySQL, como @cg/shared/dates.ts) ----------------

  static int _daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  /// DATE_ADD(d, INTERVAL n MONTH): un día inexistente pasa al último día del mes.
  static String addMonths(String iso, int n) {
    final p = iso.split('-').map(int.parse).toList();
    final total = p[0] * 12 + (p[1] - 1) + n;
    final y = total ~/ 12, mo = total % 12 + 1;
    final d = p[2] < _daysInMonth(y, mo) ? p[2] : _daysInMonth(y, mo);
    return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }

  /// LAST_DAY(d).
  static String lastDayOfMonth(String iso) {
    final p = iso.split('-').map(int.parse).toList();
    return '${iso.substring(0, 8)}${_daysInMonth(p[0], p[1]).toString().padLeft(2, '0')}';
  }
}
