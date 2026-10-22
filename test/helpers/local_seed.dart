// Base local REAL (sqflite ffi, archivo temporal) con un catálogo mínimo, para probar los
// formularios contra SQLite y no contra dobles.
import 'dart:io';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SeededDb {
  final Database db;
  final Map<String, int> accounts;
  final Map<String, int> categories;
  SeededDb(this.db, this.accounts, this.categories);

  Future<LocalCatalog> get catalog async => LocalCatalog(db);
  Future<LocalMovementWriter> get writer async => LocalMovementWriter(db);

  Future<int> count(String table, [String where = '1']) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table WHERE $where')).first['n']! as int;

  Future<int> balance(String account) async => (await db.rawQuery(
          'SELECT balance_cents AS b FROM account_balances WHERE account_local_id = ?', [accounts[account]]))
      .first['b']! as int;
}

int _n = 0;

/// Banco $1.000 (ARS), Efectivo $50 (ARS), Dolares US$100, Cerrada (inactiva);
/// categorías Comida, Super, Transferencia (TRANSFER), Ingreso (INCOME), Ticket (DEFAULT_TICKET).
Future<SeededDb> seededDb() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('cg_seed');
  final db = await LocalDatabase.open(path: p.join(dir.path, 's${_n++}.db'), factory: databaseFactoryFfi);
  final accounts = <String, int>{};
  var sid = 1;
  for (final (name, currency, active, balance) in [
    ('Banco', 'ARS', true, 100000),
    ('Efectivo', 'ARS', true, 5000),
    ('Dolares', 'USD', true, 10000),
    ('Cerrada', 'ARS', false, 0),
  ]) {
    final id = await db.insert('accounts', {'server_id': sid, 'name': name, 'currency': currency, 'active': active ? 1 : 0, 'updated_at': 'x'});
    if (balance != 0) {
      final h = await db.insert('movement_headers', {'server_id': 100 + sid, 'type': 1, 'occurred_at': '2026-01-01 10:00:00', 'updated_at': 'x'});
      await db.insert('movement_details', {'server_id': 100 + sid, 'header_local_id': h, 'account_local_id': id, 'amount_cents': balance, 'updated_at': 'x'});
    }
    accounts[name] = id;
    sid++;
  }
  final categories = <String, int>{};
  for (final (name, role) in [('Comida', null), ('Super', null), ('Transferencia', 'TRANSFER'), ('Ingreso', 'INCOME'), ('Ticket', 'DEFAULT_TICKET')]) {
    categories[name] = await db.insert('categories', {'server_id': sid++, 'name': name, 'role': role, 'updated_at': 'x'});
  }
  return SeededDb(db, accounts, categories);
}
