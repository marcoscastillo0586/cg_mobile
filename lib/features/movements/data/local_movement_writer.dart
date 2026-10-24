import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_catalog.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/outbox.dart';
import '../../../l10n/l10n.dart';

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
        final general = _concept(d.generalConcept, (l) => l.generalConcept3);
        if (d.lines.isEmpty) throw _invalid((l) => l.enterLeastOneExpense);
        if (d.lines.length > 300) throw _invalid((l) => l.most300LinesPerExpense);
        final account = await _usableAccount(catalog, d.accountLocalId, (l) => l.selectAccountDebit);
        final items = <(ExpenseLine, LocalCategory, String)>[];
        for (final (i, line) in d.lines.indexed) {
          final concept = _concept(line.concept, (l) => l.conceptLineI(i + 1));
          _positive(line.amountCents, (l) => l.lineN(i + 1));
          final cat = await catalog.category(line.categoryLocalId);
          if (cat == null) throw _invalid((l) => l.selectCategoryLineI2(i + 1));
          if (cat.reservedForExpenses) {
            throw ValidationFailure.t((l) => l.categoryNameReservedCannotUsed(cat.name), 'RESERVED_CATEGORY');
          }
          if (!cat.active) throw ValidationFailure.t((l) => l.categoryNameInactive(cat.name), 'CATEGORY_INACTIVE');
          items.add((line, cat, concept));
        }
        // Sin control de fondos: un egreso puede dejar la cuenta en negativo (el formulario avisa
        // que corresponde registrar un ingreso). Igual que el servidor.

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
        final account = await _usableAccount(catalog, d.accountLocalId, (l) => l.selectDestinationAccount2);
        final concept = _concept(d.concept, (l) => l.concept2);
        _positive(d.amountCents, (l) => l.incomeWord);
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
          throw ValidationFailure.t((l) => l.sourceDestinationAccountsCannotSame, 'SAME_ACCOUNT');
        }
        final catalog = LocalCatalog(txn);
        final from = await _usableAccount(catalog, d.fromLocalId, (l) => l.selectSourceAccount2);
        final to = await _usableAccount(catalog, d.toLocalId, (l) => l.selectDestinationAccount3);
        if (from.currency != to.currency) {
          throw ValidationFailure.t((l) => l.cannotTransferBetweenAccountsDifferent2, 'CURRENCY_MISMATCH');
        }
        _positive(d.amountCents, (l) => l.transferWord);
        final typed = d.concept.trim();
        if (typed.length > conceptMax) throw _invalid((l) => l.conceptCannotExceedConceptmaxCharacters(conceptMax));
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

  /// Corrección: borra el alta rechazada que se reemplaza (comprobante local y su operación).
  static Future<void> _dropReplaced(Transaction txn, int? seq) async {
    if (seq == null) return;
    final ops = await txn.query('outbox', where: "seq = ? AND status = 'rejected' AND action = 'create'", whereArgs: [seq]);
    if (ops.isEmpty) throw _invalid((l) => l.operationCorrectNoLongerRejected);
    await txn.delete('movement_headers', where: 'client_id = ? AND server_id IS NULL', whereArgs: [ops.single['client_id']]);
    await txn.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
  }

  // ---------------- reglas ----------------

  Future<LocalAccount> _usableAccount(LocalCatalog catalog, int localId, String Function(AppLocalizations l) missing) async {
    final account = await catalog.account(localId);
    if (account == null) throw _invalid(missing);
    if (!account.active) throw ValidationFailure.t((l) => l.accountNameInactive(account.name), 'ACCOUNT_INACTIVE');
    return account;
  }

  /// Solo transferencias (regla del servidor): el origen debe tener `saldo >= monto`
  /// (el saldo local ya descuenta lo pendiente de enviar).
  static void _assertFunds(LocalAccount account, int amountCents) {
    if (account.balanceCents < amountCents) {
      throw ValidationFailure.t(
        (l) => l.insufficientFundsTransfer(Money.format(amountCents, currency: account.currency), account.name.toUpperCase(),
            Money.format(account.balanceCents, currency: account.currency)),
        'INSUFFICIENT_FUNDS',
      );
    }
  }

  static Future<LocalCategory> _roleCategory(LocalCatalog catalog, String role) async {
    final category = await catalog.roleCategory(role);
    if (category == null) {
      throw ValidationFailure.t((l) => l.systemCategoryRoleMissingSync(role), 'CATALOG_NOT_SYNCED');
    }
    return category;
  }

  static String _concept(String value, String Function(AppLocalizations l) label) {
    final v = value.trim();
    if (v.isEmpty) throw _invalid((l) => l.fieldRequired(label(l)));
    if (v.length > conceptMax) throw _invalid((l) => l.fieldTooLong(label(l), conceptMax));
    return v;
  }

  static void _positive(int cents, String Function(AppLocalizations l) what) {
    if (cents <= 0) throw _invalid((l) => l.amountOfMustBePositive(what(l)));
  }

  static ValidationFailure _invalid(String Function(AppLocalizations l) text) => ValidationFailure.t(text);

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
