import 'package:sqflite/sqflite.dart';
import '../errors/failures.dart';
import 'outbox.dart';

/// Ayudas compartidas por las altas, bajas y cambios locales (cuentas, categorías, límites).
abstract final class LocalOps {
  static String stamp() => DateTime.now().toUtc().toIso8601String();

  /// Fecha de hoy en Buenos Aires (UTC−3, sin horario de verano), como `nowInArgentina().date`.
  static String todayAr([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().subtract(const Duration(hours: 3));
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  static ValidationFailure invalid(String message) => ValidationFailure(message, null, 'VALIDATION_ERROR');

  /// Otra fila (no eliminada) con el mismo nombre, sin distinguir mayúsculas: (local_id, active).
  static Future<(int, bool)?> sameName(DatabaseExecutor db, String table, String name, {int? exceptLocalId}) async {
    final rows = await db.query(table,
        columns: ['local_id', 'active'],
        where: 'deleted = 0 AND name = ? COLLATE NOCASE${exceptLocalId == null ? '' : ' AND local_id <> ?'}',
        whereArgs: [name, if (exceptLocalId != null) exceptLocalId],
        limit: 1);
    return rows.isEmpty ? null : (rows.first['local_id']! as int, rows.first['active'] == 1);
  }

  /// Borrado local + operación `delete`. Si es un alta que nunca se intentó enviar, se quita
  /// del celular junto con su operación (no hay nada que avisarle al servidor).
  static Future<String?> deleteRow(Transaction txn, {required String entity, required String table, required Map<String, Object?> row}) async {
    final localId = row['local_id']! as int;
    if (row['server_id'] == null) {
      final create = await txn.query('outbox',
          where: "client_id = ? AND action = 'create' AND status = 'pending' AND attempts = 0", whereArgs: [row['client_id']]);
      if (create.isNotEmpty) {
        await txn.delete('outbox', where: 'seq = ?', whereArgs: [create.single['seq']]);
        await txn.delete(table, where: 'local_id = ?', whereArgs: [localId]);
        return null;
      }
    }
    await txn.update(table, {'deleted': 1, 'deleted_at': stamp()}, where: 'local_id = ?', whereArgs: [localId]);
    return Outbox.enqueue(txn,
        entity: entity,
        action: 'delete',
        ref: ref(row),
        baseVersion: baseVersion(row),
        data: const {},
        undo: {'table': table, 'local_id': localId, 'values': {'deleted': 0, 'deleted_at': null}});
  }

  static Map<String, Object> ref(Map<String, Object?> row) =>
      row['server_id'] != null ? {'serverId': row['server_id']! as int} : {'clientId': row['client_id']! as String};

  /// Sin server_id todavía (alta pendiente): no hay versión que comparar.
  static int? baseVersion(Map<String, Object?> row) => row['server_id'] == null ? null : row['version'] as int?;

  static Future<Map<String, Object?>> require(DatabaseExecutor db, String table, int localId, String what) async {
    final rows = await db.query(table, where: 'local_id = ? AND deleted = 0', whereArgs: [localId]);
    if (rows.isEmpty) throw invalid('$what no está en el celular; sincronizá y volvé a intentar');
    return rows.single;
  }
}
