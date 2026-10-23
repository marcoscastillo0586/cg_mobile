import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/local_database.dart';

/// Cola de operaciones para `POST /sync/push` (docs/sync.md). Solo se escribe dentro de la
/// misma transacción que el cambio local: o quedan los dos, o ninguno.
class Outbox {
  Outbox._();

  /// Encola una operación y devuelve su `opId` (UUID estable: los reintentos lo reutilizan).
  static Future<String> enqueue(
    Transaction txn, {
    required String entity,
    required String action,
    String? clientId,
    Map<String, Object>? ref,
    int? baseVersion,
    required Map<String, Object?> data,
    Map<String, Object?>? undo,
  }) async {
    final opId = LocalDatabase.newId();
    final now = DateTime.now().toUtc().toIso8601String();
    await txn.insert('outbox', {
      'op_id': opId,
      'entity': entity,
      'action': action,
      'client_id': clientId,
      'ref': ref == null ? null : jsonEncode(ref),
      'base_version': baseVersion,
      'data': jsonEncode(data),
      'undo': undo == null ? null : jsonEncode(undo),
      'created_at': now,
      'updated_at': now,
    });
    return opId;
  }

  /// Tabla local de cada entidad de la API.
  static const tables = {
    'account': 'accounts',
    'category': 'categories',
    'budget': 'budgets',
    'movement': 'movement_headers',
    'movement_detail': 'movement_details',
  };

  /// Operaciones que todavía no tienen resultado del servidor.
  static Future<int> pendingCount(DatabaseExecutor db) async =>
      (await db.rawQuery("SELECT COUNT(*) AS n FROM outbox WHERE status = 'pending'")).first['n']! as int;
}
