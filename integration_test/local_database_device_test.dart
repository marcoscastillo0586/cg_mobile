// Corre EN EL CELULAR con el SQLite de Android: verifica que el esquema se cree y que las
// restricciones se apliquen ahí (no solo en la PC con ffi). Usa un archivo aparte, que se
// borra al terminar; no toca cg_local.db.
//   flutter test integration_test/local_database_device_test.dart -d <dispositivo>
//
// ATENCIÓN: flutter test reinstala la app y BORRA SUS DATOS (base local y sesión).
// No correrlo en un celular con operaciones pendientes de sincronizar.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/database/migrations.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const now = '2026-10-21T12:00:00Z';

  testWidgets('esquema y restricciones con el SQLite del dispositivo', (tester) async {
    final path = p.join(await getDatabasesPath(), 'device_constraints_test.db');
    await deleteDatabase(path);
    final db = await LocalDatabase.open(path: path);
    try {
      final version = (await db.rawQuery('select sqlite_version() as v')).first['v'];
      // ignore: avoid_print
      print('[DEVICE] SQLite del dispositivo: $version');
      expect(await db.getVersion(), latestSchemaVersion);
      expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);

      final acc = await db.insert('accounts', {'server_id': 1, 'name': 'A', 'currency': 'ARS', 'updated_at': now});
      final h = await db.insert('movement_headers',
          {'client_id': 'h1', 'type': 2, 'occurred_at': '2026-10-21 10:00:00', 'updated_at': now});
      Map<String, Object?> det(Object amount, {int account = 0}) =>
          {'header_local_id': h, 'account_local_id': account == 0 ? acc : account, 'amount_cents': amount, 'updated_at': now};

      await db.insert('movement_details', det(-150050));
      final rechazos = <String, Future<Object?> Function()>{
        'importe con decimales': () => db.insert('movement_details', det(-1500.5)),
        'moneda EUR': () => db.insert('accounts', {'server_id': 2, 'name': 'B', 'currency': 'EUR', 'updated_at': now}),
        'cuenta sin identidad': () => db.insert('accounts', {'name': 'C', 'currency': 'ARS', 'updated_at': now}),
        'clave foránea rota': () => db.insert('movement_details', det(-1, account: 999)),
        'tipo de movimiento 4': () => db.insert('movement_headers',
            {'client_id': 'h2', 'type': 4, 'occurred_at': '2026-10-21 10:00:00', 'updated_at': now}),
        'outbox alta sin client_id': () => db.insert('outbox',
            {'op_id': 'o1', 'entity': 'movement', 'action': 'create', 'created_at': now, 'updated_at': now}),
        'segunda fila de sync_state': () => db.insert('sync_state', {'id': 2}),
      };
      for (final e in rechazos.entries) {
        await expectLater(e.value(), throwsA(isA<DatabaseException>()), reason: e.key);
      }
      final saldo = await db.query('account_balances', where: 'account_local_id = ?', whereArgs: [acc]);
      expect(saldo.single['balance_cents'], -150050);
    } finally {
      await db.close();
      await deleteDatabase(path);
    }
  });
}
