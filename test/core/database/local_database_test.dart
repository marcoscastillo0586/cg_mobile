// SQLite REAL (sqflite_common_ffi) sobre archivos temporales en la PC. Prueba el esquema,
// las restricciones y las migraciones; no prueba el archivo del celular (eso se inspecciona
// por adb).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/database/migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Directory tmp;
int _n = 0;
String _path() => p.join(tmp.path, 'db_${_n++}.db');
const now = '2026-10-21T12:00:00Z';

Future<Database> _fresh() => LocalDatabase.open(path: _path(), factory: databaseFactoryFfi);

Future<List<String>> _schema(Database db) async {
  final rows = await db.rawQuery(
    "SELECT type || ' ' || name || ': ' || COALESCE(sql, '') AS s FROM sqlite_master "
    "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
  );
  return rows.map((r) => r['s']! as String).toList();
}

Future<int> _account(Database db, {String? clientId, int? serverId, String currency = 'ARS'}) => db.insert('accounts', {
      'server_id': serverId,
      'client_id': clientId,
      'name': 'Efectivo',
      'currency': currency,
      'updated_at': now,
    });

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    tmp = Directory.systemTemp.createTempSync('cg_local_db_test');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('creación desde cero: versión, tablas, vista y fila única de sync_state', () async {
    final db = await _fresh();
    expect(await db.getVersion(), latestSchemaVersion);
    expect(latestSchemaVersion, 2);
    final names = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type IN ('table','view')"))
        .map((r) => r['name'])
        .toSet();
    expect(names, containsAll(<String>[
      'accounts', 'categories', 'budgets', 'budget_categories', 'budget_accounts',
      'movement_headers', 'movement_details', 'outbox', 'sync_state', 'account_balances',
    ]));
    expect(await db.query('sync_state'), [
      {'id': 1, 'cursor': null, 'last_pull_at': null, 'last_push_at': null},
    ]);
    expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
    await db.close();
  });

  test('migración 1 → 2: conserva los datos y el esquema queda igual al de una base nueva', () async {
    // Base creada por una app con solo la migración 1.
    final path = _path();
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final sql in migrations.first.statements) {
              await db.execute(sql);
            }
          },
        ));
    final acc = await _account(v1, serverId: 7);
    await v1.close();

    final upgraded = await LocalDatabase.open(path: path, factory: databaseFactoryFfi);
    expect(await upgraded.getVersion(), 2);
    expect((await upgraded.query('accounts')).single['local_id'], acc);
    expect(await upgraded.query('sync_state'), hasLength(1));

    final fresh = await _fresh();
    expect(await _schema(upgraded), await _schema(fresh));
    await upgraded.close();
    await fresh.close();
  });

  test('una base más nueva que la app no se abre (no se pierde nada)', () async {
    final path = _path();
    final future = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(version: 99));
    await future.close();
    await expectLater(LocalDatabase.open(path: path, factory: databaseFactoryFfi), throwsA(isA<StateError>()));
  });

  group('restricciones', () {
    late Database db;
    setUp(() async => db = await _fresh());
    tearDown(() => db.close());

    Future<int> header({int type = 2, String at = '2026-10-21 10:00:00', int deleted = 0}) => db.insert('movement_headers', {
          'client_id': LocalDatabase.newId(),
          'type': type,
          'occurred_at': at,
          'deleted': deleted,
          'updated_at': now,
        });

    test('importes: un REAL (decimal) se rechaza; un entero se acepta', () async {
      final a = await _account(db, serverId: 1);
      final h = await header();
      Map<String, Object?> det(Object amount) =>
          {'header_local_id': h, 'account_local_id': a, 'amount_cents': amount, 'updated_at': now};
      await db.insert('movement_details', det(-150050));
      await expectLater(db.insert('movement_details', det(-1500.5)), throwsA(isA<DatabaseException>()));
      await expectLater(
        db.insert('budgets', {'client_id': 'b1', 'start_date': '2026-10-01', 'end_date': '2026-10-31', 'limit_cents': 10.5, 'updated_at': now}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('moneda solo ARS o USD', () async {
      await _account(db, serverId: 1, currency: 'USD');
      await expectLater(_account(db, serverId: 2, currency: 'EUR'), throwsA(isA<DatabaseException>()));
    });

    test('identidad: hace falta server_id o client_id, y ambos son únicos', () async {
      await expectLater(_account(db), throwsA(isA<DatabaseException>()));
      await _account(db, clientId: 'c-1');
      await expectLater(_account(db, clientId: 'c-1'), throwsA(isA<DatabaseException>()));
      await _account(db, serverId: 5);
      await expectLater(_account(db, serverId: 5), throwsA(isA<DatabaseException>()));
    });

    test('claves foráneas: un renglón no puede apuntar a una cuenta o encabezado inexistente', () async {
      final h = await header();
      await expectLater(
        db.insert('movement_details', {'header_local_id': h, 'account_local_id': 999, 'amount_cents': -1, 'updated_at': now}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('presupuesto: hasta >= desde y límite > 0', () async {
      Map<String, Object?> b(String s, String e, int l) =>
          {'client_id': LocalDatabase.newId(), 'start_date': s, 'end_date': e, 'limit_cents': l, 'updated_at': now};
      await db.insert('budgets', b('2026-10-01', '2026-10-31', 100));
      await expectLater(db.insert('budgets', b('2026-10-31', '2026-10-01', 100)), throwsA(isA<DatabaseException>()));
      await expectLater(db.insert('budgets', b('2026-10-01', '2026-10-31', 0)), throwsA(isA<DatabaseException>()));
    });

    test('tipo de movimiento 1, 2 o 3 y fecha con formato del servidor', () async {
      await header(type: 3);
      await expectLater(header(type: 4), throwsA(isA<DatabaseException>()));
      await expectLater(header(at: '2026-10-21'), throwsA(isA<DatabaseException>()));
    });

    test('outbox: alta exige client_id, edición/baja exige ref; op_id único; orden por seq', () async {
      Map<String, Object?> op(String id, String action, {String? clientId, String? ref}) => {
            'op_id': id,
            'entity': 'movement',
            'action': action,
            'client_id': clientId,
            'ref': ref,
            'created_at': now,
            'updated_at': now,
          };
      await db.insert('outbox', op('op-1', 'create', clientId: 'mov-1'));
      await db.insert('outbox', op('op-2', 'update', ref: '{"serverId":7}'));
      await expectLater(db.insert('outbox', op('op-3', 'create')), throwsA(isA<DatabaseException>()));
      await expectLater(db.insert('outbox', op('op-4', 'delete')), throwsA(isA<DatabaseException>()));
      await expectLater(db.insert('outbox', op('op-1', 'create', clientId: 'otro')), throwsA(isA<DatabaseException>()));
      await expectLater(
        db.insert('outbox', {...op('op-5', 'create', clientId: 'x'), 'entity': 'ticket'}),
        throwsA(isA<DatabaseException>()),
      );
      final rows = await db.query('outbox', orderBy: 'seq');
      expect(rows.map((r) => r['op_id']), ['op-1', 'op-2']);
      expect(rows.first['status'], 'pending');
    });

    test('sync_state tiene una sola fila', () async {
      await expectLater(db.insert('sync_state', {'id': 2}), throwsA(isA<DatabaseException>()));
    });

    test('vista de saldos: suma en vivo, sin renglones ni encabezados borrados', () async {
      final a = await _account(db, serverId: 1);
      final b = await _account(db, serverId: 2);
      final h1 = await header();
      final h2 = await header(deleted: 1);
      Future<void> det(int h, int acc, int c, {int deleted = 0}) => db.insert('movement_details',
          {'header_local_id': h, 'account_local_id': acc, 'amount_cents': c, 'deleted': deleted, 'updated_at': now});
      await det(h1, a, 1000000);
      await det(h1, a, -250050);
      await det(h1, a, -999, deleted: 1); // renglón borrado
      await det(h2, a, -500000); // encabezado borrado
      Future<Map<int, int>> saldos() async => {
            for (final r in await db.query('account_balances'))
              r['account_local_id']! as int: r['balance_cents']! as int,
          };
      expect(await saldos(), {a: 749950, b: 0});
      // Un cambio se refleja en el acto: no hay caché que actualizar.
      await det(h1, b, 123);
      expect((await saldos())[b], 123);
    });
  });
}
