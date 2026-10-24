import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../errors/exceptions.dart';
import '../network/dio_client.dart';
import 'outbox.dart';
import 'pull_service.dart';

/// Operación que no quedó aplicada (para el detalle de la sincronización).
class PushIssue {
  final int seq;
  final String status; // pending (error temporal) | rejected | conflict
  final String? code;
  final String? message;
  const PushIssue(this.seq, this.status, this.code, this.message);

  @override
  String toString() => '#$seq $status${code == null ? '' : ' $code'}${message == null ? '' : ': $message'}';
}

class PushResult {
  final int sent;
  final int applied;
  final int duplicate;
  final List<PushIssue> issues;
  const PushResult({required this.sent, required this.applied, required this.duplicate, required this.issues});

  int count(String status) => issues.where((i) => i.status == status).length;

  /// Éxito solo si todo lo enviado quedó aplicado.
  bool get complete => issues.isEmpty;
}

/// Envía la outbox con `POST /sync/push` (docs/sync.md):
/// - en orden de `seq`, en lotes; cada operación con su `opId` y `clientId` ESTABLES (un
///   reintento reenvía exactamente lo mismo y el servidor responde `duplicate`);
/// - `applied`/`duplicate`: guarda serverId y version (remapeo clientId → serverId) y
///   reescribe las referencias `{clientId}` de las operaciones que siguen en la cola;
/// - `rejected`: revierte el cambio local (el saldo vuelve a ser el del servidor) y queda para
///   corregir o descartar; `TEMPORARY_ERROR` queda pendiente con el mismo opId;
/// - `conflict`: gana el servidor (se aplica `current`); queda para aceptar o reintentar.
/// Un error de red o de sesión corta el envío: lo no respondido queda pendiente.
/// No tiene bloqueo propio: lo llama solo [SyncController], que serializa push y pull.
class PushService {
  final Database _db;
  final DioClient _client;
  final int batchSize;

  PushService(this._db, this._client, {this.batchSize = 100});

  Future<PushResult> push() async {
    final deviceId = (await _db.query('sync_state', columns: ['device_id'])).single['device_id'] as String?;
    final tried = <int>{};
    var sent = 0, applied = 0, duplicate = 0;
    final issues = <PushIssue>[];

    while (true) {
      final ops = await _db.query(
        'outbox',
        where: "status = 'pending'${tried.isEmpty ? '' : ' AND seq NOT IN (${tried.join(',')})'}",
        orderBy: 'seq',
        limit: batchSize,
      );
      if (ops.isEmpty) break;
      tried.addAll(ops.map((o) => o['seq']! as int));
      sent += ops.length;
      for (final (op, result) in await _send(ops, deviceId)) {
        switch (await _apply(op, result)) {
          case 'applied':
            applied++;
          case 'duplicate':
            duplicate++;
          case final status:
            final error = result?['error'] as Map<String, dynamic>?;
            issues.add(PushIssue(op['seq']! as int, status, error?['code'] as String?, error?['message'] as String?));
        }
      }
    }
    if (sent > 0) {
      await _db.update('sync_state', {'last_push_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = 1');
    }
    return PushResult(sent: sent, applied: applied, duplicate: duplicate, issues: issues);
  }

  /// Envía un lote. Si el servidor rechaza el lote entero por validación (400), se reenvía
  /// de a una para aislar la operación inválida en vez de trabar la cola.
  Future<List<(Map<String, Object?>, Map<String, dynamic>?)>> _send(List<Map<String, Object?>> ops, String? deviceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_attempt_at = ? WHERE seq IN (${ops.map((o) => o['seq']).join(',')})',
      [now],
    );
    try {
      final body = await _client.post('/sync/push', data: {
        if (deviceId != null) 'deviceId': deviceId,
        'operations': [for (final o in ops) _wire(o)],
      });
      final results = body is Map<String, dynamic> && body['results'] is List
          ? (body['results'] as List).cast<Map<String, dynamic>>()
          : throw const ServerException('Sincronización: respuesta del push inesperada', null, 'UNEXPECTED_RESPONSE');
      final byOp = {for (final r in results) r['opId'] as String: r};
      return [for (final o in ops) (o, byOp[o['op_id']])];
    } on ServerException catch (e) {
      if (e.statusCode != 400) rethrow;
      if (ops.length > 1) {
        return [for (final o in ops) ...await _send([o], deviceId)];
      }
      // Una sola operación que el servidor no acepta ni como lote: se rechaza localmente.
      return [
        (ops.single, {'opId': ops.single['op_id'], 'status': 'rejected', 'error': {'code': e.code ?? 'VALIDATION_ERROR', 'message': e.message}}),
      ];
    }
  }

  static Map<String, Object?> _wire(Map<String, Object?> o) => {
        'opId': o['op_id'],
        'entity': o['entity'],
        'action': o['action'],
        if (o['client_id'] != null) 'clientId': o['client_id'],
        if (o['ref'] != null) 'ref': jsonDecode(o['ref']! as String),
        if (o['base_version'] != null) 'baseVersion': o['base_version'],
        'data': jsonDecode(o['data']! as String),
      };

  /// Aplica el resultado de una operación en una transacción y devuelve el estado final.
  Future<String> _apply(Map<String, Object?> op, Map<String, dynamic>? r) async {
    final seq = op['seq']! as int;
    if (r == null) {
      debugPrint('[PUSH] Sin resultado del servidor para la operación #$seq: queda pendiente');
      return 'pending';
    }
    final status = r['status'] as String?;
    final code = (r['error'] as Map<String, dynamic>?)?['code'] as String?;
    final table = Outbox.tables[op['entity']];
    final now = DateTime.now().toUtc().toIso8601String();
    return _db.transaction((txn) async {
      Future<void> mark(String s) =>
          txn.update('outbox', {'status': s, 'server_result': jsonEncode(r), 'updated_at': now}, where: 'seq = ?', whereArgs: [seq]);

      switch (status) {
        case 'applied' || 'duplicate':
          final serverId = r['serverId'] as int?;
          final version = r['version'] as int?;
          if (op['action'] == 'create' && serverId != null && table != null) {
            await txn.update(table, {'server_id': serverId, 'version': version},
                where: 'client_id = ? AND (server_id IS NULL OR server_id = ?)', whereArgs: [op['client_id'], serverId]);
            await _rewriteRefs(txn, op['client_id']! as String, serverId);
          } else if (op['action'] == 'update' && serverId != null && table != null && version != null && table != 'movement_details') {
            // movement_details no guarda versión (el pull no la trae): sus ediciones van sin baseVersion.
            await txn.update(table, {'version': version}, where: 'server_id = ?', whereArgs: [serverId]);
          }
          await mark(status!);
          return status;
        case 'rejected' when code == 'TEMPORARY_ERROR':
          // No se registró en el servidor: queda pendiente y se reintenta con el MISMO opId.
          await txn.update('outbox', {'server_result': jsonEncode(r), 'updated_at': now}, where: 'seq = ?', whereArgs: [seq]);
          return 'pending';
        case 'rejected':
          await revert(txn, op);
          await mark('rejected');
          return 'rejected';
        case 'conflict':
          final current = r['current'];
          if (op['entity'] == 'movement' && current is Map<String, dynamic>) {
            // Gana el servidor: el dato local se reemplaza por `current`.
            await PullService(_db, _client).upsertMovement(txn, {...current, 'id': r['serverId'], 'version': r['version']});
          }
          await mark('conflict');
          return 'conflict';
        default:
          throw ServerException('Sincronización: estado de operación desconocido "$status"', null, 'UNEXPECTED_RESPONSE');
      }
    });
  }

  /// Deshace el cambio local de una operación (rechazada o descartada): un alta deja de
  /// contar (el comprobante queda eliminado); una edición vuelve a los valores guardados en `undo`.
  static Future<void> revert(Transaction txn, Map<String, Object?> op) async {
    final table = Outbox.tables[op['entity']];
    if (op['action'] == 'create' && table != null) {
      await txn.update(table, {'deleted': 1, 'deleted_at': DateTime.now().toUtc().toIso8601String()},
          where: 'client_id = ? AND server_id IS NULL', whereArgs: [op['client_id']]);
    } else if (op['undo'] != null) {
      // Una fila ({table, local_id, values}) o varias (lista), p. ej. el par de una transferencia.
      final undo = jsonDecode(op['undo']! as String);
      for (final u in (undo is List ? undo : [undo]).cast<Map<String, dynamic>>()) {
        await txn.update(u['table'] as String, (u['values'] as Map).cast<String, Object?>(),
            where: 'local_id = ?', whereArgs: [u['local_id']]);
      }
    }
  }

  /// Las operaciones siguientes que referenciaban la alta por clientId pasan a usar su serverId.
  static Future<void> _rewriteRefs(Transaction txn, String clientId, int serverId) async {
    final from = jsonEncode({'clientId': clientId});
    final to = jsonEncode({'serverId': serverId});
    await txn.rawUpdate(
      "UPDATE outbox SET data = REPLACE(data, ?, ?), ref = REPLACE(ref, ?, ?) WHERE status IN ('pending', 'conflict') AND (instr(data, ?) > 0 OR instr(ref, ?) > 0)",
      [from, to, from, to, from, from],
    );
  }
}
