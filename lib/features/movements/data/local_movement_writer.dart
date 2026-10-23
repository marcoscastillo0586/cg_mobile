import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_catalog.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/outbox.dart';

/// Largo máximo de un concepto (CONCEPT_MAX de @cg/shared).
const conceptMax = 150;

class ExpenseLine {
  final String concept;
  final int categoryLocalId;
  final int amountCents;
  const ExpenseLine({required this.concept, required this.categoryLocalId, required this.amountCents});
}

class ExpenseDraft {
  final int accountLocalId;
  final DateTime date;
  final String generalConcept;
  final List<ExpenseLine> lines;
  const ExpenseDraft({required this.accountLocalId, required this.date, required this.generalConcept, required this.lines});
}

class IncomeDraft {
  final int accountLocalId;
  final DateTime date;
  final String concept;
  final int amountCents;
  const IncomeDraft({required this.accountLocalId, required this.date, required this.concept, required this.amountCents});
}

class TransferDraft {
  final int fromLocalId;
  final int toLocalId;
  final int amountCents;
  final DateTime date;

  /// Vacío = el del servidor: "Transferencia desde X hacia Y".
  final String concept;
  const TransferDraft({required this.fromLocalId, required this.toLocalId, required this.amountCents, required this.date, this.concept = ''});
}

/// Resultado de guardar: quedó en SQLite y en la cola, todavía sin enviar.
class SavedMovement {
  final int headerLocalId;
  final String clientId;
  final String opId;
  const SavedMovement(this.headerLocalId, this.clientId, this.opId);
}

final localMovementWriterProvider = Provider<Future<LocalMovementWriter>>(
  (ref) async => LocalMovementWriter(await ref.watch(localDatabaseProvider)),
);

/// Altas de egresos, ingresos y transferencias SIN red: escriben el comprobante en SQLite y
/// la operación en la outbox en una sola transacción. Valida las mismas reglas que el
/// servidor (movement-writer.service.ts) contra el saldo local, que ya incluye lo pendiente.
/// Si una regla no se cumple, lanza [ValidationFailure] con el código de la API y no escribe nada.
class LocalMovementWriter {
  final Database _db;
  final DateTime Function() _now;

  LocalMovementWriter(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// [replacingSeq]: corrige un alta rechazada (la reemplaza en la misma transacción).
  Future<SavedMovement> createExpense(ExpenseDraft d, {int? replacingSeq}) => _db.transaction((txn) async {
        final catalog = LocalCatalog(txn);
        final general = _concept(d.generalConcept, 'El concepto general');
        if (d.lines.isEmpty) throw _invalid('Debe ingresar al menos un gasto');
        if (d.lines.length > 300) throw _invalid('Máximo 300 renglones por egreso');
        final account = await _usableAccount(catalog, d.accountLocalId, 'Debe seleccionar un lugar para realizar el débito');
        final items = <(ExpenseLine, LocalCategory, String)>[];
        for (final (i, line) in d.lines.indexed) {
          final concept = _concept(line.concept, 'El concepto del renglón ${i + 1}');
          _positive(line.amountCents, 'renglón ${i + 1}');
          final cat = await catalog.category(line.categoryLocalId);
          if (cat == null) throw _invalid('Seleccione una categoría en el renglón ${i + 1}');
          if (cat.reservedForExpenses) {
            throw ValidationFailure('La categoría ${cat.name} es reservada y no puede usarse en egresos', null, 'RESERVED_CATEGORY');
          }
          if (!cat.active) throw ValidationFailure('La categoría ${cat.name} está inactiva', null, 'CATEGORY_INACTIVE');
          items.add((line, cat, concept));
        }
        final total = d.lines.fold<int>(0, (s, l) => s + l.amountCents);
        _assertFunds(account, total);

        await _dropReplaced(txn, replacingSeq);
        final clientId = LocalDatabase.newId();
        final headerId = await _insertHeader(txn, 2, general, d.date, clientId);
        for (final (line, cat, concept) in items) {
          // Signo contable: los egresos se guardan negativos.
          await _insertDetail(txn, headerId, account.localId, cat.localId, concept, -line.amountCents);
        }
        final opId = await Outbox.enqueue(txn, entity: 'movement', action: 'create', clientId: clientId, data: {
          'type': 2,
          'accountRef': account.ref,
          'date': _isoDate(d.date),
          'generalConcept': general,
          'items': [
            for (final (line, cat, concept) in items)
              {'concept': concept, 'categoryRef': cat.ref, 'amount': Money.toApiDecimal(line.amountCents)},
          ],
        });
        return SavedMovement(headerId, clientId, opId);
      });

  Future<SavedMovement> createIncome(IncomeDraft d, {int? replacingSeq}) => _db.transaction((txn) async {
        final catalog = LocalCatalog(txn);
        final account = await _usableAccount(catalog, d.accountLocalId, 'Debe seleccionar la cuenta de destino');
        final concept = _concept(d.concept, 'El concepto');
        _positive(d.amountCents, 'ingreso');
        final category = await _roleCategory(catalog, CategoryRoles.income);

        await _dropReplaced(txn, replacingSeq);
        final clientId = LocalDatabase.newId();
        final headerId = await _insertHeader(txn, 1, concept, d.date, clientId);
        await _insertDetail(txn, headerId, account.localId, category.localId, concept, d.amountCents);
        final opId = await Outbox.enqueue(txn, entity: 'movement', action: 'create', clientId: clientId, data: {
          'type': 1,
          'accountRef': account.ref,
          'date': _isoDate(d.date),
          'concept': concept,
          'amount': Money.toApiDecimal(d.amountCents),
        });
        return SavedMovement(headerId, clientId, opId);
      });

  Future<SavedMovement> createTransfer(TransferDraft d, {int? replacingSeq}) => _db.transaction((txn) async {
        if (d.fromLocalId == d.toLocalId) {
          throw const ValidationFailure('La cuenta de origen y de destino no pueden ser iguales', null, 'SAME_ACCOUNT');
        }
        final catalog = LocalCatalog(txn);
        final from = await _usableAccount(catalog, d.fromLocalId, 'Seleccione la cuenta de origen');
        final to = await _usableAccount(catalog, d.toLocalId, 'Seleccione la cuenta de destino');
        if (from.currency != to.currency) {
          throw const ValidationFailure(
            'No se puede transferir entre cuentas de distinta moneda. Registrá un egreso y un ingreso con la cotización usada.',
            null,
            'CURRENCY_MISMATCH',
          );
        }
        _positive(d.amountCents, 'transferencia');
        final typed = d.concept.trim();
        if (typed.length > conceptMax) throw _invalid('El concepto no puede superar $conceptMax caracteres');
        _assertFunds(from, d.amountCents);
        final category = await _roleCategory(catalog, CategoryRoles.transfer);
        final concept = typed.isNotEmpty ? typed : 'Transferencia desde ${from.name.toUpperCase()} hacia ${to.name.toUpperCase()}';

        await _dropReplaced(txn, replacingSeq);
        final clientId = LocalDatabase.newId();
        final headerId = await _insertHeader(txn, 3, concept, d.date, clientId);
        // Partida doble, en el mismo orden que el servidor: crédito en destino y débito en origen.
        await _insertDetail(txn, headerId, to.localId, category.localId, concept, d.amountCents);
        await _insertDetail(txn, headerId, from.localId, category.localId, concept, -d.amountCents);
        final opId = await Outbox.enqueue(txn, entity: 'movement', action: 'create', clientId: clientId, data: {
          'type': 3,
          'fromRef': from.ref,
          'toRef': to.ref,
          'amount': Money.toApiDecimal(d.amountCents),
          'date': _isoDate(d.date),
          if (typed.isNotEmpty) 'concept': typed,
        });
        return SavedMovement(headerId, clientId, opId);
      });

  /// Edición mínima del encabezado (concepto general y/o fecha; la hora se conserva, como
  /// `MovementEditService.updateHeader`). Se aplica en la base local y se encola un `update`
  /// con `baseVersion` = versión conocida del servidor, para detectar conflictos.
  Future<String> updateHeader(int headerLocalId, {String? generalConcept, DateTime? date}) => _db.transaction((txn) async {
        final rows = await txn.query('movement_headers', where: 'local_id = ? AND deleted = 0', whereArgs: [headerLocalId]);
        if (rows.isEmpty) throw _invalid('El comprobante no está en el celular; sincronizá y volvé a intentar');
        final h = rows.single;
        final before = {'general_concept': h['general_concept'], 'occurred_at': h['occurred_at']};
        final changes = <String, Object?>{};
        final data = <String, Object?>{};
        if (generalConcept != null) {
          final c = _concept(generalConcept, 'El concepto general');
          if (c != h['general_concept']) {
            changes['general_concept'] = c;
            data['generalConcept'] = c;
          }
        }
        if (date != null) {
          final occurred = h['occurred_at']! as String;
          final next = '${_isoDate(date)} ${occurred.substring(11)}';
          if (next != occurred) {
            changes['occurred_at'] = next;
            data['date'] = _isoDate(date);
          }
        }
        if (changes.isEmpty) throw _invalid('No hay cambios para guardar');
        await txn.update('movement_headers', {...changes, 'updated_at': _now().toUtc().toIso8601String()},
            where: 'local_id = ?', whereArgs: [headerLocalId]);
        return Outbox.enqueue(
          txn,
          entity: 'movement',
          action: 'update',
          ref: syncRef(h['server_id'] as int?, h['client_id'] as String?),
          // Sin server_id todavía (alta pendiente): no hay versión que comparar.
          baseVersion: h['server_id'] == null ? null : h['version'] as int?,
          data: data,
          undo: {'table': 'movement_headers', 'local_id': headerLocalId, 'values': before},
        );
      });

  /// Corrección: borra el alta rechazada que se reemplaza (comprobante local y su operación).
  static Future<void> _dropReplaced(Transaction txn, int? seq) async {
    if (seq == null) return;
    final ops = await txn.query('outbox', where: "seq = ? AND status = 'rejected' AND action = 'create'", whereArgs: [seq]);
    if (ops.isEmpty) throw _invalid('La operación a corregir ya no está rechazada');
    await txn.delete('movement_headers', where: 'client_id = ? AND server_id IS NULL', whereArgs: [ops.single['client_id']]);
    await txn.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
  }

  // ---------------- reglas ----------------

  Future<LocalAccount> _usableAccount(LocalCatalog catalog, int localId, String missing) async {
    final account = await catalog.account(localId);
    if (account == null) throw _invalid(missing);
    if (!account.active) throw ValidationFailure('La cuenta ${account.name} está inactiva', null, 'ACCOUNT_INACTIVE');
    return account;
  }

  /// Regla del servidor: `saldo >= monto` (el saldo local ya descuenta lo pendiente de enviar).
  static void _assertFunds(LocalAccount account, int amountCents) {
    if (account.balanceCents < amountCents) {
      throw ValidationFailure(
        'Fondos insuficientes en ${account.name.toUpperCase()}: disponible '
        '${Money.format(account.balanceCents, currency: account.currency)}, '
        'necesitás ${Money.format(amountCents, currency: account.currency)}.',
        null,
        'INSUFFICIENT_FUNDS',
      );
    }
  }

  static Future<LocalCategory> _roleCategory(LocalCatalog catalog, String role) async {
    final category = await catalog.roleCategory(role);
    if (category == null) {
      throw ValidationFailure('Falta la categoría del sistema $role: sincronizá con conexión antes de cargar.', null, 'CATALOG_NOT_SYNCED');
    }
    return category;
  }

  static String _concept(String value, String label) {
    final v = value.trim();
    if (v.isEmpty) throw _invalid('$label es obligatorio');
    if (v.length > conceptMax) throw _invalid('$label no puede superar $conceptMax caracteres');
    return v;
  }

  static void _positive(int cents, String what) {
    if (cents <= 0) throw _invalid('El monto del $what debe ser mayor a cero');
  }

  static ValidationFailure _invalid(String message) => ValidationFailure(message, null, 'VALIDATION_ERROR');

  // ---------------- escritura ----------------

  Future<int> _insertHeader(Transaction txn, int type, String concept, DateTime date, String clientId) => txn.insert('movement_headers', {
        'client_id': clientId,
        'type': type,
        'occurred_at': '${_isoDate(date)} ${_argentinaTime()}',
        'general_concept': concept,
        'updated_at': _now().toUtc().toIso8601String(),
      });

  Future<void> _insertDetail(Transaction txn, int headerId, int accountId, int categoryId, String concept, int amountCents) =>
      txn.insert('movement_details', {
        'header_local_id': headerId,
        'account_local_id': accountId,
        'category_local_id': categoryId,
        'concept': concept,
        'amount_cents': amountCents,
        'updated_at': _now().toUtc().toIso8601String(),
      });

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Hora actual de Buenos Aires (UTC−3, sin horario de verano), como `MovementWriterService.occurredAt`.
  String _argentinaTime() {
    final t = _now().toUtc().subtract(const Duration(hours: 3));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
