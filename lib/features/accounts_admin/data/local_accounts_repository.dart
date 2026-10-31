import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/local_ops.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/widgets/account_avatar.dart';
import '../domain/account_item.dart';
import '../../../core/auth/current_author.dart';

/// Largo del nombre de cuenta (ACCOUNT_NAME_MIN/MAX de @cg/shared).
const accountNameMin = 2;
const accountNameMax = 15;

final localAccountsRepositoryProvider = Provider<Future<LocalAccountsRepository>>(
  (ref) async => LocalAccountsRepository(await ref.watch(localDatabaseProvider), author: ref.watch(currentAuthorProvider)),
);

/// Cuentas desde la base local, con alta, edición, activar/desactivar y baja sin conexión
/// (outbox). Mismas reglas que accounts.service.ts.
class LocalAccountsRepository {
  final Database _db;

  /// Queda como creador de las cuentas nuevas (los invitados editan solo las suyas).
  final LocalAuthor? _author;
  LocalAccountsRepository(this._db, {LocalAuthor? author}) : _author = author;

  Future<List<AccountItem>> list() async => (await _db.rawQuery('''
        SELECT a.local_id, a.server_id, a.name, a.currency, a.active, a.image_url, a.icon_ref, a.created_by_user_id, b.balance_cents,
               (SELECT COUNT(*) FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
                 WHERE d.account_local_id = a.local_id AND d.deleted = 0 AND h.deleted = 0) AS movements
        FROM accounts a JOIN account_balances b ON b.account_local_id = a.local_id
        WHERE a.deleted = 0
        ORDER BY a.name COLLATE NOCASE''')).map((r) => AccountItem(
            id: r['local_id']! as int,
            serverId: r['server_id'] as int?,
            name: r['name']! as String,
            currency: Currency.parse(r['currency']),
            active: r['active'] == 1,
            imageUrl: r['image_url'] as String?,
            iconRef: r['icon_ref'] as String?,
            balanceCents: r['balance_cents']! as int,
            movementsCount: r['movements']! as int,
            createdByUserId: r['created_by_user_id'] as int?,
          )).toList();

  Future<String> create({required String name, required Currency currency, String? iconRef}) => _db.transaction((txn) async {
        final n = _name(name);
        await _assertFreeName(txn, n);
        if (iconRef != null && !AccountIcons.byKey.containsKey(iconRef)) throw LocalOps.invalid((l) => l.unknownIcon);
        final clientId = LocalDatabase.newId();
        await txn.insert('accounts', {
          'client_id': clientId, 'name': n, 'currency': currency.code, 'active': 1, 'icon_ref': iconRef, 'updated_at': LocalOps.stamp(),
          'created_by_user_id': _author?.id,
        });
        return Outbox.enqueue(txn, entity: 'account', action: 'create', clientId: clientId, data: {
          'name': n,
          'currency': currency.code,
          if (iconRef != null) 'iconRef': iconRef,
        });
      });

  /// Nombre y/o moneda. La moneda no cambia si la cuenta tiene movimientos (CURRENCY_LOCKED).
  Future<String> update(int localId, {String? name, Currency? currency}) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'accounts', localId, (l) => l.account);
        final data = <String, Object?>{};
        final changes = <String, Object?>{};
        if (name != null) {
          final n = _name(name);
          if (n != row['name']) {
            await _assertFreeName(txn, n, exceptLocalId: localId);
            changes['name'] = n;
            data['name'] = n;
          }
        }
        if (currency != null && currency.code != row['currency']) {
          if (await _movements(txn, localId) > 0) {
            throw ValidationFailure.t((l) => l.currencyAccountMovementsCannotChange, 'CURRENCY_LOCKED');
          }
          changes['currency'] = currency.code;
          data['currency'] = currency.code;
        }
        if (data.isEmpty) throw LocalOps.invalid((l) => l.noChangesSave);
        return _enqueueUpdate(txn, row, changes, data);
      });

  /// Activar o desactivar. Solo se envía `active` (no el nombre): así el servidor no lo toca.
  /// Desactivar exige saldo ≤ 0 (ACCOUNT_HAS_FUNDS).
  Future<String> setActive(int localId, bool active) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'accounts', localId, (l) => l.account);
        if ((row['active'] == 1) == active) throw LocalOps.invalid((l) => active ? l.accountAlreadyActive : l.accountAlreadyInactive);
        if (!active) await _assertNoMoney(txn, localId);
        return _enqueueUpdate(txn, row, {'active': active ? 1 : 0}, {'active': active});
      });

  /// Baja: física si no tiene movimientos; si tiene, el servidor la desactiva (con la regla de saldo).
  Future<String?> delete(int localId) => _db.transaction((txn) async {
        final row = await LocalOps.require(txn, 'accounts', localId, (l) => l.account);
        if (await _movements(txn, localId) > 0) {
          await _assertNoMoney(txn, localId);
          await txn.update('accounts', {'active': 0, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
          return Outbox.enqueue(txn,
              entity: 'account',
              action: 'delete',
              ref: LocalOps.ref(row),
              baseVersion: LocalOps.baseVersion(row),
              data: const {},
              undo: {'table': 'accounts', 'local_id': localId, 'values': {'active': row['active']}});
        }
        return LocalOps.deleteRow(txn, entity: 'account', table: 'accounts', row: row);
      });

  // ---------------- reglas ----------------

  Future<String> _enqueueUpdate(Transaction txn, Map<String, Object?> row, Map<String, Object?> changes, Map<String, Object?> data) async {
    final localId = row['local_id']! as int;
    await txn.update('accounts', {...changes, 'updated_at': LocalOps.stamp()}, where: 'local_id = ?', whereArgs: [localId]);
    return Outbox.enqueue(txn,
        entity: 'account',
        action: 'update',
        ref: LocalOps.ref(row),
        baseVersion: LocalOps.baseVersion(row),
        data: data,
        undo: {'table': 'accounts', 'local_id': localId, 'values': {for (final k in changes.keys) k: row[k]}});
  }

  static String _name(String name) {
    final n = name.trim();
    if (n.length < accountNameMin) throw LocalOps.invalid((l) => l.nameMustHaveLeastAccountnamemin(accountNameMin));
    if (n.length > accountNameMax) throw LocalOps.invalid((l) => l.nameCannotExceedAccountnamemaxCharacters(accountNameMax));
    return n;
  }

  static Future<void> _assertFreeName(Transaction txn, String name, {int? exceptLocalId}) async {
    final same = await LocalOps.sameName(txn, 'accounts', name, exceptLocalId: exceptLocalId);
    if (same == null) return;
    // En el servidor, dar de alta un nombre inactivo la reactiva; acá se pide activarla, que es lo mismo y explícito.
    throw ValidationFailure.t((l) => same.$2 ? l.accountNameTaken : l.accountNameTakenInactive, 'DUPLICATE_NAME');
  }

  static Future<int> _movements(DatabaseExecutor db, int localId) async => (await db.rawQuery('''
        SELECT COUNT(*) AS n FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
        WHERE d.account_local_id = ? AND d.deleted = 0 AND h.deleted = 0''', [localId])).first['n']! as int;

  static Future<void> _assertNoMoney(DatabaseExecutor db, int localId) async {
    final balance = (await db.rawQuery('SELECT balance_cents FROM account_balances WHERE account_local_id = ?', [localId])).first['balance_cents']! as int;
    if (balance > 0) {
      throw ValidationFailure.t((l) => l.errAccountHasFunds, 'ACCOUNT_HAS_FUNDS');
    }
  }
}
