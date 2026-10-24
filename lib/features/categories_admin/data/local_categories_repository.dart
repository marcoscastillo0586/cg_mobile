import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/sync/local_ops.dart';
import '../../../core/sync/outbox.dart';
import '../domain/category_item.dart';

/// Largo máximo del nombre de categoría (CATEGORY_NAME_MAX de @cg/shared).
const categoryNameMax = 250;

final localCategoriesRepositoryProvider = Provider<Future<LocalCategoriesRepository>>(
  (ref) async => LocalCategoriesRepository(await ref.watch(localDatabaseProvider)),
);

/// Categorías desde la base local, con alta, renombrar, activar/desactivar y baja sin conexión
/// (outbox). Las reservadas (TRANSFER, INCOME, DEFAULT_TICKET) no se tocan.
class LocalCategoriesRepository {
  final Database _db;
  LocalCategoriesRepository(this._db);

  Future<List<CategoryItem>> list() async => (await _db.rawQuery('''
        SELECT c.local_id, c.server_id, c.name, c.active, c.role, c.version,
               (SELECT COUNT(*) FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
                 WHERE d.category_local_id = c.local_id AND d.deleted = 0 AND h.deleted = 0) AS movements
        FROM categories c WHERE c.deleted = 0
        ORDER BY c.name COLLATE NOCASE''')).map((r) => CategoryItem(
            id: r['local_id']! as int,
            serverId: r['server_id'] as int?,
            name: r['name']! as String,
            active: r['active'] == 1,
            role: CategoryRole.parse(r['role']),
            movementsCount: r['movements']! as int,
            version: r['version'] as int?,
          )).toList();

  Future<String> create(String name) => _db.transaction((txn) async {
        final n = _name(name);
        await _assertFreeName(txn, n);
        final clientId = LocalDatabase.newId();
        await txn.insert('categories', {'client_id': clientId, 'name': n, 'active': 1, 'updated_at': LocalOps.stamp()});
        return Outbox.enqueue(txn, entity: 'category', action: 'create', clientId: clientId, data: {'name': n});
      });

  Future<String> rename(int localId, String name) => _db.transaction((txn) async {
        final row = await _editable(txn, localId);
        final n = _name(name);
        if (n == row['name']) throw LocalOps.invalid('No hay cambios para guardar');
        await _assertFreeName(txn, n, exceptLocalId: localId);
        return _enqueueUpdate(txn, row, {'name': n}, {'name': n});
      });

  /// Activar: se envía solo `active: true` (no el nombre).
  /// Desactivar: se envía `category:delete`, que en el servidor es lo mismo que
  /// `update {active:false}` (ambos llaman a categories.remove: la borra si no tiene
  /// movimientos, la desactiva si tiene) pero maneja bien el borrado físico. Con `update`, el
  /// servidor borraba la categoría y después fallaba al leer su versión (TEMPORARY_ERROR y
  /// luego UNKNOWN_REF al reintentar). La baja física llega en el próximo pull.
  Future<String> setActive(int localId, bool active) => _db.transaction((txn) async {
        final row = await _editable(txn, localId);
        if ((row['active'] == 1) == active) throw LocalOps.invalid(active ? 'La categoría ya está activa' : 'La categoría ya está inactiva');
        if (active) return _enqueueUpdate(txn, row, {'active': 1}, {'active': true});
        await txn.update('categories', {'active': 0, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
        return Outbox.enqueue(txn,
            entity: 'category',
            action: 'delete',
            ref: LocalOps.ref(row),
            baseVersion: LocalOps.baseVersion(row),
            data: const {},
            undo: {'table': 'categories', 'local_id': localId, 'values': {'active': row['active']}});
      });

  Future<String?> delete(int localId) => _db.transaction((txn) async {
        final row = await _editable(txn, localId);
        final used = (await txn.rawQuery('''
            SELECT COUNT(*) AS n FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
            WHERE d.category_local_id = ? AND d.deleted = 0 AND h.deleted = 0''', [localId])).first['n']! as int;
        if (used > 0) {
          // Con movimientos el servidor la desactiva (baja lógica).
          await txn.update('categories', {'active': 0, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
          return Outbox.enqueue(txn,
              entity: 'category',
              action: 'delete',
              ref: LocalOps.ref(row),
              baseVersion: LocalOps.baseVersion(row),
              data: const {},
              undo: {'table': 'categories', 'local_id': localId, 'values': {'active': row['active']}});
        }
        return LocalOps.deleteRow(txn, entity: 'category', table: 'categories', row: row);
      });

  // ---------------- reglas ----------------

  static Future<Map<String, Object?>> _editable(Transaction txn, int localId) async {
    final row = await LocalOps.require(txn, 'categories', localId, 'La categoría');
    if (row['role'] != null) {
      throw const ValidationFailure('Las categorías reservadas del sistema no pueden modificarse ni eliminarse', null, 'RESERVED_CATEGORY');
    }
    return row;
  }

  Future<String> _enqueueUpdate(Transaction txn, Map<String, Object?> row, Map<String, Object?> changes, Map<String, Object?> data) async {
    final localId = row['local_id']! as int;
    await txn.update('categories', {...changes, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
    return Outbox.enqueue(txn,
        entity: 'category',
        action: 'update',
        ref: LocalOps.ref(row),
        baseVersion: LocalOps.baseVersion(row),
        data: data,
        undo: {'table': 'categories', 'local_id': localId, 'values': {for (final k in changes.keys) k: row[k]}});
  }

  static String _name(String name) {
    final n = name.trim();
    if (n.isEmpty) throw LocalOps.invalid('El nombre de la categoría es obligatorio');
    if (n.length > categoryNameMax) throw LocalOps.invalid('El nombre no puede superar $categoryNameMax caracteres');
    return n;
  }

  static Future<void> _assertFreeName(Transaction txn, String name, {int? exceptLocalId}) async {
    final same = await LocalOps.sameName(txn, 'categories', name, exceptLocalId: exceptLocalId);
    if (same == null) return;
    throw ValidationFailure(
      same.$2 ? 'Ya existe una categoría con ese nombre' : 'Ya existe una categoría inactiva con ese nombre: activala',
      null,
      'DUPLICATE_NAME',
    );
  }
}
