import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database.dart';
import '../errors/failures.dart';
import '../money/money.dart';
import 'outbox.dart';
import 'push_service.dart';

/// Alta rechazada lista para corregir en su formulario (ids LOCALES e importes en centavos).
class CorrectionSource {
  final int seq;
  final int type; // 1 ingreso, 2 egreso, 3 transferencia
  final DateTime date;
  final String concept; // concepto general (egreso) o concepto (ingreso/transferencia)
  final int? accountLocalId; // egreso/ingreso
  final int? fromLocalId; // transferencia
  final int? toLocalId;
  final int amountCents; // ingreso/transferencia
  final List<({String concept, int? categoryLocalId, int amountCents})> lines; // egreso

  const CorrectionSource({
    required this.seq,
    required this.type,
    required this.date,
    required this.concept,
    this.accountLocalId,
    this.fromLocalId,
    this.toLocalId,
    this.amountCents = 0,
    this.lines = const [],
  });
}

/// Operación de la outbox que no quedó aplicada, para la pantalla "Pendientes y rechazados".
class OutboxEntry {
  final int seq;
  final String opId;
  final String entity;
  final String action;
  final String status; // pending | rejected | conflict
  final int attempts;
  final String? errorCode;
  final String? errorMessage;
  final String description;
  final String createdAt;

  /// Edición solo de concepto y/o fecha del encabezado (lo único que se reintenta con "mis cambios").
  final bool headerFieldsOnly;

  const OutboxEntry({
    required this.seq,
    required this.opId,
    required this.entity,
    required this.action,
    required this.status,
    required this.attempts,
    required this.errorCode,
    required this.errorMessage,
    required this.description,
    required this.createdAt,
    this.headerFieldsOnly = false,
  });

  bool get isMovementCreate => entity == 'movement' && action == 'create';
  bool get isMovementUpdate => entity == 'movement' && action == 'update';

  /// Descartar no puede perder datos del servidor: solo lo rechazado, en conflicto o lo que
  /// nunca se intentó enviar (lo ya enviado podría estar aplicado y la respuesta perdida).
  bool get canDiscard => status == 'rejected' || status == 'conflict' || (status == 'pending' && attempts == 0);
  bool get canCorrect => status == 'rejected' && isMovementCreate;
  bool get canRetryMine => status == 'conflict' && isMovementUpdate && headerFieldsOnly;
}

final outboxRepositoryProvider = Provider<Future<OutboxRepository>>((ref) async => OutboxRepository(await ref.watch(localDatabaseProvider)));

class OutboxRepository {
  final Database _db;
  OutboxRepository(this._db);

  Future<List<OutboxEntry>> unresolved() async {
    final rows = await _db.query('outbox', where: "status IN ('pending', 'rejected', 'conflict')", orderBy: 'seq');
    return [for (final r in rows) await _entry(_db, r)];
  }

  Future<OutboxEntry> _entry(DatabaseExecutor db, Map<String, Object?> r) async {
    final result = r['server_result'] == null ? null : jsonDecode(r['server_result']! as String) as Map<String, dynamic>;
    final error = result?['error'] as Map<String, dynamic>?;
    final data = jsonDecode(r['data']! as String) as Map<String, dynamic>;
    return OutboxEntry(
      headerFieldsOnly: data.isNotEmpty && data.keys.every((k) => k == 'generalConcept' || k == 'date'),
      seq: r['seq']! as int,
      opId: r['op_id']! as String,
      entity: r['entity']! as String,
      action: r['action']! as String,
      status: r['status']! as String,
      attempts: r['attempts']! as int,
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
      description: await _describe(db, r),
      createdAt: r['created_at']! as String,
    );
  }

  Future<String> _describe(DatabaseExecutor db, Map<String, Object?> r) async {
    final d = jsonDecode(r['data']! as String) as Map<String, dynamic>;
    if (r['entity'] == 'movement' && r['action'] == 'create') {
      final type = d['type'] as int;
      final cents = type == 2
          ? (d['items'] as List).fold<int>(0, (s, i) => s + (Money.parseInput((i as Map)['amount'] as String) ?? 0))
          : Money.parseInput(d['amount'] as String) ?? 0;
      return switch (type) {
        1 => 'Ingreso "${d['concept']}" ${Money.format(cents)} en ${await _accountName(db, d['accountRef'])} · ${d['date']}',
        2 => 'Egreso "${d['generalConcept']}" ${Money.format(cents)} de ${await _accountName(db, d['accountRef'])} · ${d['date']}',
        _ => 'Transferencia ${Money.format(cents)} de ${await _accountName(db, d['fromRef'])} a ${await _accountName(db, d['toRef'])} · ${d['date']}',
      };
    }
    final ref = r['ref'] == null ? null : jsonDecode(r['ref']! as String);
    final target = ref is Map && ref['serverId'] != null ? ' #${ref['serverId']}' : '';
    if (r['entity'] == 'movement' && r['action'] == 'update') {
      final t = d['transfer'] as Map<String, dynamic>?;
      final parts = [
        if (d['generalConcept'] != null) 'concepto "${d['generalConcept']}"',
        if (d['date'] != null) 'fecha ${d['date']}',
        if (d['accountRef'] != null) 'cuenta ${await _accountName(db, d['accountRef'])}',
        if (t != null)
          'transferencia ${Money.format(Money.parseInput(t['amount'] as String) ?? 0)} de ${await _accountName(db, t['fromRef'])} a ${await _accountName(db, t['toRef'])}',
      ];
      return 'Edición de comprobante$target: ${parts.join(', ')}';
    }
    if (r['entity'] == 'movement' && r['action'] == 'delete') return 'Eliminación de comprobante$target';
    if (r['entity'] == 'movement_detail' && r['action'] == 'update') {
      final parts = [
        if (d['concept'] != null) 'concepto "${d['concept']}"',
        if (d['amount'] != null) 'monto ${Money.format(Money.parseInput(d['amount'] as String) ?? 0)}',
        if (d['categoryRef'] != null) 'categoría',
      ];
      return 'Edición de renglón$target: ${parts.join(', ')}';
    }
    if (r['entity'] == 'movement_detail' && r['action'] == 'delete') return 'Eliminación de renglón$target';
    return '${r['entity']} / ${r['action']}';
  }

  Future<String> _accountName(DatabaseExecutor db, Object? ref) async {
    final id = await _localId(db, 'accounts', ref);
    if (id == null) return '(cuenta desconocida)';
    return ((await db.query('accounts', columns: ['name'], where: 'local_id = ?', whereArgs: [id])).single['name']! as String).toUpperCase();
  }

  Future<int?> _localId(DatabaseExecutor db, String table, Object? ref) async {
    if (ref is! Map) return null;
    final rows = ref['serverId'] != null
        ? await db.query(table, columns: ['local_id'], where: 'server_id = ?', whereArgs: [ref['serverId']])
        : await db.query(table, columns: ['local_id'], where: 'client_id = ?', whereArgs: [ref['clientId']]);
    return rows.isEmpty ? null : rows.first['local_id'] as int;
  }

  Future<Map<String, Object?>> _op(DatabaseExecutor db, int seq) async {
    final rows = await db.query('outbox', where: 'seq = ?', whereArgs: [seq]);
    if (rows.isEmpty) throw const ValidationFailure('La operación ya no está en la cola', null, 'VALIDATION_ERROR');
    return rows.single;
  }

  /// Descarta la operación y revierte su efecto local (el saldo vuelve a ser el del servidor).
  /// Conflicto: el dato local ya es el del servidor; descartar = aceptar la versión del servidor.
  Future<void> discard(int seq) => _db.transaction((txn) async {
        final op = await _op(txn, seq);
        final entry = await _entry(txn, op);
        if (!entry.canDiscard) {
          throw const ValidationFailure(
            'Ya se intentó enviar: podría estar aplicada en el servidor. Sincronizá antes de descartarla.', null, 'VALIDATION_ERROR');
        }
        if (op['status'] == 'pending') await PushService.revert(txn, op);
        final table = Outbox.tables[op['entity']];
        if (op['action'] == 'create' && table != null) {
          // El alta nunca llegó al servidor: el comprobante local se borra del todo.
          await txn.delete(table, where: 'client_id = ? AND server_id IS NULL', whereArgs: [op['client_id']]);
        }
        await txn.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
      });

  /// Conflicto en una edición del comprobante: vuelve a aplicar MIS cambios y los reencola con
  /// un opId nuevo y `baseVersion` = versión actual del servidor (docs/sync.md).
  Future<void> retryMine(int seq) => _db.transaction((txn) async {
        final op = await _op(txn, seq);
        final entry = await _entry(txn, op);
        if (!entry.canRetryMine) throw const ValidationFailure('Solo se reintentan ediciones en conflicto', null, 'VALIDATION_ERROR');
        final result = jsonDecode(op['server_result']! as String) as Map<String, dynamic>;
        final serverId = result['serverId'] as int;
        final data = jsonDecode(op['data']! as String) as Map<String, dynamic>;
        final rows = await txn.query('movement_headers', where: 'server_id = ? AND deleted = 0', whereArgs: [serverId]);
        if (rows.isEmpty) throw const ValidationFailure('El comprobante ya no existe en el celular', null, 'VALIDATION_ERROR');
        final h = rows.single;
        final occurred = h['occurred_at']! as String;
        final changes = <String, Object?>{
          if (data['generalConcept'] != null) 'general_concept': data['generalConcept'],
          if (data['date'] != null) 'occurred_at': '${data['date']} ${occurred.substring(11)}',
        };
        await txn.update('movement_headers', changes, where: 'local_id = ?', whereArgs: [h['local_id']]);
        await Outbox.enqueue(
          txn,
          entity: 'movement',
          action: 'update',
          ref: {'serverId': serverId},
          baseVersion: result['version'] as int?,
          data: data,
          undo: {
            'table': 'movement_headers',
            'local_id': h['local_id'],
            'values': {'general_concept': h['general_concept'], 'occurred_at': occurred},
          },
        );
        await txn.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
      });

  /// Datos del alta rechazada para abrir su formulario y corregirla.
  Future<CorrectionSource> correction(int seq) async {
    final op = await _op(_db, seq);
    if (!(await _entry(_db, op)).canCorrect) throw const ValidationFailure('Solo se corrigen altas rechazadas', null, 'VALIDATION_ERROR');
    final d = jsonDecode(op['data']! as String) as Map<String, dynamic>;
    final type = d['type'] as int;
    final date = DateTime.parse(d['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10));
    int cents(Object? v) => Money.parseInput(v as String) ?? 0;
    return switch (type) {
      2 => CorrectionSource(
          seq: seq,
          type: 2,
          date: date,
          concept: d['generalConcept'] as String,
          accountLocalId: await _localId(_db, 'accounts', d['accountRef']),
          lines: [
            for (final i in (d['items'] as List).cast<Map<String, dynamic>>())
              (concept: i['concept'] as String, categoryLocalId: await _localId(_db, 'categories', i['categoryRef']), amountCents: cents(i['amount'])),
          ],
        ),
      1 => CorrectionSource(
          seq: seq, type: 1, date: date, concept: d['concept'] as String,
          accountLocalId: await _localId(_db, 'accounts', d['accountRef']), amountCents: cents(d['amount'])),
      _ => CorrectionSource(
          seq: seq, type: 3, date: date, concept: d['concept'] as String? ?? '',
          fromLocalId: await _localId(_db, 'accounts', d['fromRef']), toLocalId: await _localId(_db, 'accounts', d['toRef']),
          amountCents: cents(d['amount'])),
    };
  }
}
