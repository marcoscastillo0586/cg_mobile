import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_catalog.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/outbox.dart';
import 'local_movement_writer.dart' show conceptMax;
import '../../../l10n/l10n.dart';

/// Renglón de un comprobante, tal como está en la base local.
class EditableDetail {
  final int localId;
  final int? serverId;
  final int accountLocalId;
  final String accountName;
  final Currency currency;
  final int? categoryLocalId;
  final String? categoryName;
  final String? concept;

  /// Con signo contable (egresos negativos).
  final int amountCents;

  const EditableDetail({
    required this.localId,
    required this.serverId,
    required this.accountLocalId,
    required this.accountName,
    required this.currency,
    required this.categoryLocalId,
    required this.categoryName,
    required this.concept,
    required this.amountCents,
  });
}

/// Comprobante para la pantalla de edición (todo desde SQLite: funciona sin conexión).
class EditableMovement {
  final int localId;
  final int? serverId;
  final String? clientId;
  final int type; // 1 ingreso, 2 egreso, 3 transferencia
  final String occurredAt;
  final String? generalConcept;
  final int? version;
  final List<EditableDetail> details;

  const EditableMovement({
    required this.localId,
    required this.serverId,
    required this.clientId,
    required this.type,
    required this.occurredAt,
    required this.generalConcept,
    required this.version,
    required this.details,
  });

  bool get isTransfer => type == 3;

  /// Ya está en el servidor (sus renglones tienen id del servidor y se pueden editar uno por uno).
  bool get synced => serverId != null && details.every((d) => d.serverId != null);

  /// Regla del servidor (deleteDetail): solo si hay más de un renglón y no es transferencia.
  bool get canDeleteDetail => !isTransfer && details.length > 1;

  EditableDetail? get transferFrom => isTransfer ? details.where((d) => d.amountCents < 0).firstOrNull : null;
  EditableDetail? get transferTo => isTransfer ? details.where((d) => d.amountCents > 0).firstOrNull : null;
}

final localMovementEditorProvider = Provider<Future<LocalMovementEditor>>(
  (ref) async => LocalMovementEditor(await ref.watch(localDatabaseProvider)),
);

/// Ediciones y borrados SIN red: cambian la base local y encolan la operación en la outbox en la
/// misma transacción, con lo necesario para deshacerla si el servidor la rechaza o se descarta.
/// Mismas reglas que movement-edit.service.ts. Saldo (regla del usuario, 2026-10-23): editar
/// egresos/ingresos puede dejar una cuenta en negativo (la pantalla avisa y pide confirmar);
/// editar una transferencia no puede dejar el origen en negativo si empeora su saldo.
class LocalMovementEditor {
  final Database _db;
  final DateTime Function() _now;

  LocalMovementEditor(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  // ---------------- lectura ----------------

  Future<EditableMovement?> loadByServerId(int serverId) async {
    final rows = await _db.query('movement_headers', columns: ['local_id'], where: 'server_id = ? AND deleted = 0', whereArgs: [serverId]);
    return rows.isEmpty ? null : load(rows.first['local_id']! as int);
  }

  Future<EditableMovement?> load(int headerLocalId) => _load(_db, headerLocalId);

  static Future<EditableMovement?> _load(DatabaseExecutor db, int headerLocalId) async {
    final hs = await db.query('movement_headers', where: 'local_id = ? AND deleted = 0', whereArgs: [headerLocalId]);
    if (hs.isEmpty) return null;
    final h = hs.single;
    final ds = await db.rawQuery('''
      SELECT d.local_id, d.server_id, d.account_local_id, a.name AS account_name, a.currency, d.category_local_id,
             c.name AS category_name, d.concept, d.amount_cents
      FROM movement_details d
      JOIN accounts a ON a.local_id = d.account_local_id
      LEFT JOIN categories c ON c.local_id = d.category_local_id
      WHERE d.header_local_id = ? AND d.deleted = 0
      ORDER BY d.local_id''', [headerLocalId]);
    return EditableMovement(
      localId: headerLocalId,
      serverId: h['server_id'] as int?,
      clientId: h['client_id'] as String?,
      type: h['type']! as int,
      occurredAt: h['occurred_at']! as String,
      generalConcept: h['general_concept'] as String?,
      version: h['version'] as int?,
      details: [
        for (final d in ds)
          EditableDetail(
            localId: d['local_id']! as int,
            serverId: d['server_id'] as int?,
            accountLocalId: d['account_local_id']! as int,
            accountName: d['account_name']! as String,
            currency: Currency.parse(d['currency']),
            categoryLocalId: d['category_local_id'] as int?,
            categoryName: d['category_name'] as String?,
            concept: d['concept'] as String?,
            amountCents: d['amount_cents']! as int,
          ),
      ],
    );
  }

  /// Saldo local de una cuenta (incluye lo pendiente de enviar).
  Future<int> balanceOf(int accountLocalId) async => _balance(_db, accountLocalId);

  static Future<int> _balance(DatabaseExecutor db, int accountLocalId) async =>
      (await db.rawQuery('SELECT balance_cents FROM account_balances WHERE account_local_id = ?', [accountLocalId])).first['balance_cents']! as int;

  // ---------------- encabezado ----------------

  /// Concepto general, fecha (se conserva la hora) y/o cuenta de todos los renglones (no en transferencias).
  Future<String> updateHeader(int headerLocalId, {String? generalConcept, DateTime? date, int? accountLocalId}) => _db.transaction((txn) async {
        final m = await _require(txn, headerLocalId);
        final changes = <String, Object?>{};
        final data = <String, Object?>{};
        final undo = <Map<String, Object?>>[];
        if (generalConcept != null) {
          final c = _concept(generalConcept, (l) => l.generalConcept3);
          if (c != m.generalConcept) {
            changes['general_concept'] = c;
            data['generalConcept'] = c;
          }
        }
        if (date != null) {
          final next = '${_isoDate(date)} ${m.occurredAt.substring(11)}';
          if (next != m.occurredAt) {
            changes['occurred_at'] = next;
            data['date'] = _isoDate(date);
          }
        }
        if (accountLocalId != null && m.details.any((d) => d.accountLocalId != accountLocalId)) {
          if (m.isTransfer) {
            throw ValidationFailure.t((l) => l.changeAccountsTransferEditSource, 'TRANSFER_EDIT');
          }
          final target = await _usableAccount(txn, accountLocalId);
          if (m.details.isNotEmpty && m.details.every((d) => d.currency != target.currency)) {
            throw ValidationFailure.t((l) => l.movementCannotMovedAccountAnother, 'CURRENCY_MISMATCH');
          }
          for (final d in m.details) {
            undo.add({'table': 'movement_details', 'local_id': d.localId, 'values': {'account_local_id': d.accountLocalId}});
          }
          await txn.update('movement_details', {'account_local_id': accountLocalId, 'updated_at': _stamp()},
              where: 'header_local_id = ? AND deleted = 0', whereArgs: [headerLocalId]);
          data['accountRef'] = target.ref;
        }
        if (data.isEmpty) throw _invalid((l) => l.noChangesSave);
        if (changes.isNotEmpty) {
          undo.add({'table': 'movement_headers', 'local_id': headerLocalId, 'values': {'general_concept': m.generalConcept, 'occurred_at': m.occurredAt}});
          await txn.update('movement_headers', {...changes, 'updated_at': _stamp()}, where: 'local_id = ?', whereArgs: [headerLocalId]);
        }
        return Outbox.enqueue(txn, entity: 'movement', action: 'update', ref: _headerRef(m), baseVersion: _baseVersion(m), data: data, undo: undo);
      });

  // ---------------- renglón ----------------

  /// Concepto, categoría y/o monto (positivo; el signo lo da el tipo) de un renglón de egreso o ingreso.
  Future<String> updateDetail(int detailLocalId, {String? concept, int? categoryLocalId, int? amountCents}) => _db.transaction((txn) async {
        final (m, d) = await _detail(txn, detailLocalId);
        if (m.isTransfer) {
          throw ValidationFailure.t((l) => l.transferLinesEditedAsPair, 'TRANSFER_EDIT');
        }
        _requireSynced(d);
        final changes = <String, Object?>{};
        final data = <String, Object?>{};
        if (concept != null) {
          final c = _concept(concept, (l) => l.concept2);
          if (c != d.concept) {
            changes['concept'] = c;
            data['concept'] = c;
          }
        }
        if (categoryLocalId != null && categoryLocalId != d.categoryLocalId) {
          if (m.type == 1) {
            throw ValidationFailure.t((l) => l.incomesAlwaysUseReservedIncome, 'RESERVED_CATEGORY');
          }
          final cat = await LocalCatalog(txn).category(categoryLocalId);
          if (cat == null) throw _invalid((l) => l.selectCategory);
          if (cat.reservedForExpenses) {
            throw ValidationFailure.t((l) => l.categoryNameReservedCannotUsed(cat.name), 'RESERVED_CATEGORY');
          }
          if (!cat.active) throw ValidationFailure.t((l) => l.categoryNameInactive(cat.name), 'CATEGORY_INACTIVE');
          changes['category_local_id'] = categoryLocalId;
          data['categoryRef'] = cat.ref;
        }
        if (amountCents != null) {
          if (amountCents <= 0) throw _invalid((l) => l.amountMustGreaterThanZero);
          final signed = m.type == 2 ? -amountCents : amountCents;
          if (signed != d.amountCents) {
            changes['amount_cents'] = signed;
            data['amount'] = Money.toApiDecimal(amountCents);
          }
        }
        if (data.isEmpty) throw _invalid((l) => l.noChangesSave);
        await txn.update('movement_details', {...changes, 'updated_at': _stamp()}, where: 'local_id = ?', whereArgs: [detailLocalId]);
        // Los renglones se referencian por serverId y van sin baseVersion (el pull no trae su versión).
        return Outbox.enqueue(txn,
            entity: 'movement_detail',
            action: 'update',
            ref: {'serverId': d.serverId!},
            data: data,
            undo: {
              'table': 'movement_details',
              'local_id': d.localId,
              'values': {'concept': d.concept, 'category_local_id': d.categoryLocalId, 'amount_cents': d.amountCents},
            });
      });

  /// Borra un renglón: solo si el comprobante tiene más de uno y no es transferencia.
  Future<String> deleteDetail(int detailLocalId) => _db.transaction((txn) async {
        final (m, d) = await _detail(txn, detailLocalId);
        if (m.isTransfer) {
          throw ValidationFailure.t((l) => l.singleLineTransferCannotDeleted, 'TRANSFER_EDIT');
        }
        if (m.details.length <= 1) {
          throw ValidationFailure.t((l) => l.onlyLineVoucherDeleteWhole, 'LAST_DETAIL');
        }
        _requireSynced(d);
        await txn.update('movement_details', {'deleted': 1, 'deleted_at': _stamp()}, where: 'local_id = ?', whereArgs: [detailLocalId]);
        return Outbox.enqueue(txn,
            entity: 'movement_detail',
            action: 'delete',
            ref: {'serverId': d.serverId!},
            data: const {},
            undo: {'table': 'movement_details', 'local_id': d.localId, 'values': {'deleted': 0, 'deleted_at': null}});
      });

  // ---------------- transferencia ----------------

  /// Reemplaza origen, destino y monto (siempre como par). El origen no puede quedar en
  /// negativo si su saldo empeora (regla del servidor: `after < 0 && after < before`).
  Future<String> updateTransfer(int headerLocalId, {required int fromLocalId, required int toLocalId, required int amountCents}) =>
      _db.transaction((txn) async {
        final m = await _require(txn, headerLocalId);
        if (!m.isTransfer) throw ValidationFailure.t((l) => l.movementNotTransfer, 'NOT_TRANSFER');
        final from = m.transferFrom, to = m.transferTo;
        if (from == null || to == null) throw _invalid((l) => l.transferDoesNotHaveIts);
        if (fromLocalId == toLocalId) {
          throw ValidationFailure.t((l) => l.sourceDestinationAccountsCannotSame, 'SAME_ACCOUNT');
        }
        final newFrom = await _usableAccount(txn, fromLocalId);
        final newTo = await _usableAccount(txn, toLocalId);
        if (newFrom.currency != newTo.currency) {
          throw ValidationFailure.t((l) => l.cannotTransferBetweenAccountsDifferent, 'CURRENCY_MISMATCH');
        }
        if (amountCents <= 0) throw _invalid((l) => l.amountMustGreaterThanZero);
        if (fromLocalId == from.accountLocalId && toLocalId == to.accountLocalId && amountCents == to.amountCents) {
          throw _invalid((l) => l.noChangesSave);
        }
        // Saldo de cada cuenta tocada: antes y después de reemplazar el par.
        final touched = {from.accountLocalId, to.accountLocalId, fromLocalId, toLocalId};
        for (final acc in touched) {
          final before = await _balance(txn, acc);
          var after = before;
          if (acc == from.accountLocalId) after -= from.amountCents;
          if (acc == to.accountLocalId) after -= to.amountCents;
          if (acc == fromLocalId) after -= amountCents;
          if (acc == toLocalId) after += amountCents;
          if (after < 0 && after < before) {
            final a = (await LocalCatalog(txn).account(acc))!;
            throw ValidationFailure.t(
              (l) => l.insufficientFundsTransferEdit(Money.format(before - after, currency: a.currency), a.name.toUpperCase()),
              'INSUFFICIENT_FUNDS',
            );
          }
        }
        await txn.update('movement_details', {'account_local_id': toLocalId, 'amount_cents': amountCents, 'updated_at': _stamp()},
            where: 'local_id = ?', whereArgs: [to.localId]);
        await txn.update('movement_details', {'account_local_id': fromLocalId, 'amount_cents': -amountCents, 'updated_at': _stamp()},
            where: 'local_id = ?', whereArgs: [from.localId]);
        return Outbox.enqueue(txn,
            entity: 'movement',
            action: 'update',
            ref: _headerRef(m),
            baseVersion: _baseVersion(m),
            data: {'transfer': {'fromRef': newFrom.ref, 'toRef': newTo.ref, 'amount': Money.toApiDecimal(amountCents)}},
            undo: [
              {'table': 'movement_details', 'local_id': to.localId, 'values': {'account_local_id': to.accountLocalId, 'amount_cents': to.amountCents}},
              {'table': 'movement_details', 'local_id': from.localId, 'values': {'account_local_id': from.accountLocalId, 'amount_cents': from.amountCents}},
            ]);
      });

  // ---------------- comprobante ----------------

  /// Borra el comprobante completo. Si es un alta que nunca se intentó enviar, se quita del
  /// celular junto con su operación (no hay nada que avisarle al servidor). Devuelve el opId
  /// encolado, o null si no hizo falta encolar.
  Future<String?> deleteMovement(int headerLocalId) => _db.transaction((txn) async {
        final m = await _require(txn, headerLocalId);
        if (m.serverId == null) {
          final create = await txn.query('outbox',
              where: "client_id = ? AND action = 'create' AND status = 'pending' AND attempts = 0", whereArgs: [m.clientId]);
          if (create.isNotEmpty) {
            await txn.delete('outbox', where: 'seq = ?', whereArgs: [create.single['seq']]);
            await txn.delete('movement_headers', where: 'local_id = ?', whereArgs: [headerLocalId]);
            return null;
          }
        }
        await txn.update('movement_headers', {'deleted': 1, 'deleted_at': _stamp()}, where: 'local_id = ?', whereArgs: [headerLocalId]);
        return Outbox.enqueue(txn,
            entity: 'movement',
            action: 'delete',
            ref: _headerRef(m),
            baseVersion: _baseVersion(m),
            data: const {},
            undo: {'table': 'movement_headers', 'local_id': headerLocalId, 'values': {'deleted': 0, 'deleted_at': null}});
      });

  // ---------------- reglas y ayudas ----------------

  static Future<EditableMovement> _require(Transaction txn, int headerLocalId) async {
    final m = await _load(txn, headerLocalId);
    if (m == null) throw _invalid((l) => l.voucherNotPhoneSyncTry);
    return m;
  }

  static Future<(EditableMovement, EditableDetail)> _detail(Transaction txn, int detailLocalId) async {
    final rows = await txn.query('movement_details', columns: ['header_local_id'], where: 'local_id = ? AND deleted = 0', whereArgs: [detailLocalId]);
    if (rows.isEmpty) throw _invalid((l) => l.lineNoLongerPhone);
    final m = await _require(txn, rows.single['header_local_id']! as int);
    return (m, m.details.firstWhere((d) => d.localId == detailLocalId));
  }

  /// Los renglones se referencian por serverId: un alta todavía no enviada no se edita por renglón.
  static void _requireSynced(EditableDetail d) {
    if (d.serverId == null) {
      throw _invalid((l) => l.voucherHasNotReachedServer);
    }
  }

  static Future<LocalAccount> _usableAccount(Transaction txn, int localId) async {
    final a = await LocalCatalog(txn).account(localId);
    if (a == null) throw _invalid((l) => l.selectAccount);
    if (!a.active) throw ValidationFailure.t((l) => l.accountNameInactive(a.name), 'ACCOUNT_INACTIVE');
    return a;
  }

  static Map<String, Object> _headerRef(EditableMovement m) => syncRef(m.serverId, m.clientId);

  /// Sin server_id todavía (alta pendiente): no hay versión que comparar.
  static int? _baseVersion(EditableMovement m) => m.serverId == null ? null : m.version;

  static String _concept(String value, String Function(AppLocalizations l) label) {
    final v = value.trim();
    if (v.isEmpty) throw _invalid((l) => l.fieldRequired(label(l)));
    if (v.length > conceptMax) throw _invalid((l) => l.fieldTooLong(label(l), conceptMax));
    return v;
  }

  static ValidationFailure _invalid(String Function(AppLocalizations l) text) => ValidationFailure.t(text);

  String _stamp() => _now().toUtc().toIso8601String();

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

