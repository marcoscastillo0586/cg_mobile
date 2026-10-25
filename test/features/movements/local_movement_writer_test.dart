// SQLite REAL (ffi, archivo en disco). Prueba las altas sin conexión: comprobante + outbox en
// una transacción y las reglas del servidor. No prueba la red ni el celular: eso se verifica
// en el dispositivo (modo avión) consultando su cg_local.db.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_editor.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Directory tmp;
int _n = 0;

int firstInt(List<Map<String, Object?>> rows) => rows.first.values.first! as int;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    tmp = Directory.systemTemp.createTempSync('cg_writer_test');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  late String path;
  late Database db;
  late LocalMovementWriter writer;
  final now = DateTime.utc(2026, 10, 22, 2, 30, 15); // 23:30:15 del 21/10 en Buenos Aires
  final date = DateTime(2026, 10, 21);

  // Ids locales del catálogo sembrado.
  late int banco, efectivo, dolares, cerrada, nueva, comida, transfer, income, inactiva;

  Future<int> account(String name, {int? serverId, String? clientId, String currency = 'ARS', bool active = true, int balance = 0}) async {
    final id = await db.insert('accounts', {
      'server_id': serverId, 'client_id': clientId, 'name': name, 'currency': currency, 'active': active ? 1 : 0, 'updated_at': 'x',
    });
    if (balance != 0) {
      final h = await db.insert('movement_headers', {'server_id': 9000 + id, 'type': 1, 'occurred_at': '2026-01-01 10:00:00', 'updated_at': 'x'});
      await db.insert('movement_details', {'server_id': 9000 + id, 'header_local_id': h, 'account_local_id': id, 'amount_cents': balance, 'updated_at': 'x'});
    }
    return id;
  }

  Future<int> category(String name, int serverId, {String? role, bool active = true}) =>
      db.insert('categories', {'server_id': serverId, 'name': name, 'role': role, 'active': active ? 1 : 0, 'updated_at': 'x'});

  Future<int> balance(int accountLocalId) async =>
      firstInt(await db.rawQuery('SELECT balance_cents FROM account_balances WHERE account_local_id = ?', [accountLocalId]));
  Future<int> count(String table) async => firstInt(await db.rawQuery('SELECT COUNT(*) FROM $table'));
  Future<Map<String, Object?>> lastOp() async => (await db.query('outbox', orderBy: 'seq DESC', limit: 1)).single;

  setUp(() async {
    path = p.join(tmp.path, 'w${_n++}.db');
    db = await LocalDatabase.open(path: path, factory: databaseFactoryFfi);
    writer = LocalMovementWriter(db, now: () => now);
    banco = await account('Banco', serverId: 1, balance: 100000); // $ 1.000,00
    efectivo = await account('Efectivo', serverId: 2, balance: 5000);
    dolares = await account('Dolares', serverId: 3, currency: 'USD', balance: 10000);
    cerrada = await account('Cerrada', serverId: 4, active: false, balance: 100000);
    nueva = await account('Billetera', clientId: 'acc-offline-uuid'); // creada offline, sin server_id
    comida = await category('Comida', 7);
    transfer = await category('Transferencia', 1, role: 'TRANSFER');
    income = await category('Ingreso', 2, role: 'INCOME');
    inactiva = await category('Vieja', 8, active: false);
  });
  tearDown(() => db.close());

  Future<void> expectRule(Future<Object?> Function() f, String code) async {
    final headers = await count('movement_headers'), ops = await count('outbox');
    await expectLater(f(), throwsA(isA<ValidationFailure>().having((e) => e.code, 'code', code)));
    expect(await count('movement_headers'), headers, reason: 'no debe quedar nada escrito');
    expect(await count('outbox'), ops);
  }

  group('egreso', () {
    test('escribe comprobante, renglones negativos y la operación en la outbox; descuenta el saldo', () async {
      final r = await writer.createExpense(ExpenseDraft(accountLocalId: banco, date: date, generalConcept: ' Kiosco ', lines: [
        ExpenseLine(concept: 'Alfajor', categoryLocalId: comida, amountCents: 15050),
        ExpenseLine(concept: 'Agua', categoryLocalId: comida, amountCents: 20000),
      ]));
      final h = (await db.query('movement_headers', where: 'local_id = ?', whereArgs: [r.headerLocalId])).single;
      expect(h['server_id'], isNull);
      expect(h['client_id'], r.clientId);
      expect(h['type'], 2);
      expect(h['occurred_at'], '2026-10-21 23:30:15');
      expect(h['general_concept'], 'Kiosco');
      final d = await db.query('movement_details', where: 'header_local_id = ?', whereArgs: [r.headerLocalId], orderBy: 'local_id');
      expect(d.map((x) => x['amount_cents']), [-15050, -20000]);
      expect(await balance(banco), 100000 - 35050);

      final op = await lastOp();
      expect(op['op_id'], r.opId);
      expect(op['status'], 'pending');
      expect((op['entity'], op['action'], op['client_id']), ('movement', 'create', r.clientId));
      expect(jsonDecode(op['data']! as String), {
        'type': 2,
        'accountRef': {'serverId': 1},
        'date': '2026-10-21',
        'generalConcept': 'Kiosco',
        'items': [
          {'concept': 'Alfajor', 'categoryRef': {'serverId': 7}, 'amount': '150.50'},
          {'concept': 'Agua', 'categoryRef': {'serverId': 7}, 'amount': '200.00'},
        ],
      });
    });

    test('sin fondos se guarda igual y la cuenta queda en negativo (el dinero puede no estar cargado)', () async {
      await writer.createExpense(ExpenseDraft(accountLocalId: efectivo, date: date, generalConcept: 'x',
          lines: [ExpenseLine(concept: 'a', categoryLocalId: comida, amountCents: 5001)]));
      expect(await balance(efectivo), -1);
      final op = await lastOp();
      expect(op['status'], 'pending');
    });

    test('una transferencia posterior sin fondos se guarda igual (R2: el servidor decide al enviarla)', () async {
      await writer.createExpense(ExpenseDraft(accountLocalId: banco, date: date, generalConcept: 'x',
          lines: [ExpenseLine(concept: 'a', categoryLocalId: comida, amountCents: 60000)]));
      await writer.createTransfer(TransferDraft(fromLocalId: banco, toLocalId: efectivo, amountCents: 40001, date: date));
      expect(await balance(banco), 100000 - 60000 - 40001);
      expect((await lastOp())['status'], 'pending');
    });

    test('categorías reservadas o inactivas, cuenta inactiva y datos vacíos se rechazan', () async {
      ExpenseDraft draft({int? cat, int? acc, String gc = 'x', String concept = 'a', int amount = 100}) => ExpenseDraft(
          accountLocalId: acc ?? banco, date: date, generalConcept: gc,
          lines: [ExpenseLine(concept: concept, categoryLocalId: cat ?? comida, amountCents: amount)]);
      await expectRule(() => writer.createExpense(draft(cat: transfer)), 'RESERVED_CATEGORY');
      await expectRule(() => writer.createExpense(draft(cat: income)), 'RESERVED_CATEGORY');
      await expectRule(() => writer.createExpense(draft(cat: inactiva)), 'CATEGORY_INACTIVE');
      await expectRule(() => writer.createExpense(draft(acc: cerrada)), 'ACCOUNT_INACTIVE');
      await expectRule(() => writer.createExpense(draft(gc: '  ')), 'VALIDATION_ERROR');
      await expectRule(() => writer.createExpense(draft(concept: '')), 'VALIDATION_ERROR');
      await expectRule(() => writer.createExpense(draft(amount: 0)), 'VALIDATION_ERROR');
      await expectRule(() => writer.createExpense(draft(gc: 'x' * 151)), 'VALIDATION_ERROR');
      await expectRule(() => writer.createExpense(ExpenseDraft(accountLocalId: banco, date: date, generalConcept: 'x', lines: const [])), 'VALIDATION_ERROR');
    });
  });

  group('ingreso', () {
    test('renglón positivo con la categoría INCOME; cuenta creada offline va por clientId', () async {
      final r = await writer.createIncome(IncomeDraft(accountLocalId: nueva, date: date, concept: 'Sueldo', amountCents: 123456));
      final d = (await db.query('movement_details', where: 'header_local_id = ?', whereArgs: [r.headerLocalId])).single;
      expect((d['amount_cents'], d['category_local_id']), (123456, income));
      expect(await balance(nueva), 123456);
      expect(jsonDecode((await lastOp())['data']! as String), {
        'type': 1, 'accountRef': {'clientId': 'acc-offline-uuid'}, 'date': '2026-10-21', 'concept': 'Sueldo', 'amount': '1234.56',
      });
    });

    test('sin la categoría INCOME descargada no se inventa: CATALOG_NOT_SYNCED', () async {
      await db.delete('categories', where: 'local_id = ?', whereArgs: [income]);
      await expectRule(() => writer.createIncome(IncomeDraft(accountLocalId: banco, date: date, concept: 'x', amountCents: 1)), 'CATALOG_NOT_SYNCED');
    });
  });

  group('transferencia', () {
    test('par crédito/débito con TRANSFER, concepto por defecto como el servidor y sin "concept" en la operación', () async {
      final r = await writer.createTransfer(TransferDraft(fromLocalId: banco, toLocalId: efectivo, amountCents: 30000, date: date));
      final d = await db.query('movement_details', where: 'header_local_id = ?', whereArgs: [r.headerLocalId], orderBy: 'local_id');
      expect(d.map((x) => (x['account_local_id'], x['amount_cents'], x['category_local_id'])),
          [(efectivo, 30000, transfer), (banco, -30000, transfer)]);
      final h = (await db.query('movement_headers', where: 'local_id = ?', whereArgs: [r.headerLocalId])).single;
      expect(h['general_concept'], 'Transferencia desde BANCO hacia EFECTIVO');
      expect((await balance(banco), await balance(efectivo)), (70000, 35000));
      expect(jsonDecode((await lastOp())['data']! as String), {
        'type': 3, 'fromRef': {'serverId': 1}, 'toRef': {'serverId': 2}, 'amount': '300.00', 'date': '2026-10-21',
      });
    });

    test('misma cuenta, distinta moneda y cuenta inactiva se rechazan; sin fondos no (lo decide el servidor)', () async {
      TransferDraft t(int from, int to, [int amount = 100]) => TransferDraft(fromLocalId: from, toLocalId: to, amountCents: amount, date: date);
      await expectRule(() => writer.createTransfer(t(banco, banco)), 'SAME_ACCOUNT');
      await expectRule(() => writer.createTransfer(t(banco, dolares)), 'CURRENCY_MISMATCH');
      await expectRule(() => writer.createTransfer(t(cerrada, banco)), 'ACCOUNT_INACTIVE');
      await writer.createTransfer(t(efectivo, banco, 5001));
      expect(await balance(efectivo), -1);
    });

    test('concepto escrito por el usuario se guarda y se envía', () async {
      await writer.createTransfer(TransferDraft(fromLocalId: banco, toLocalId: efectivo, amountCents: 1, date: date, concept: ' Extraccion '));
      expect((jsonDecode((await lastOp())['data']! as String) as Map)['concept'], 'Extraccion');
    });
  });

  test('atómico: si la outbox falla, el comprobante tampoco queda', () async {
    await db.execute("CREATE TRIGGER falla BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'outbox rota (simulado)'); END");
    await expectLater(
      writer.createIncome(IncomeDraft(accountLocalId: banco, date: date, concept: 'x', amountCents: 1)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await count('movement_headers'), 4); // solo los sembrados
    expect(await balance(banco), 100000);
  });

  test('las operaciones siguen en el archivo al cerrar y reabrir la base, en orden y con su op_id', () async {
    final ops = [
      await writer.createExpense(ExpenseDraft(accountLocalId: banco, date: date, generalConcept: 'a',
          lines: [ExpenseLine(concept: 'a', categoryLocalId: comida, amountCents: 100)])),
      await writer.createIncome(IncomeDraft(accountLocalId: banco, date: date, concept: 'b', amountCents: 200)),
      await writer.createTransfer(TransferDraft(fromLocalId: banco, toLocalId: efectivo, amountCents: 300, date: date)),
    ];
    await db.close();
    db = await LocalDatabase.open(path: path, factory: databaseFactoryFfi);
    final rows = await db.query('outbox', orderBy: 'seq');
    expect(rows.map((r) => r['op_id']), ops.map((o) => o.opId));
    expect(rows.map((r) => r['status']).toSet(), {'pending'});
    expect(ops.map((o) => o.opId).toSet(), hasLength(3));
  });

  group('edición mínima del encabezado', () {
    test('comprobante del servidor: conserva la hora, encola update con ref serverId, baseVersion y undo', () async {
      final hid = (await db.query('movement_headers', where: 'server_id = ?', whereArgs: [9000 + banco])).single['local_id']! as int;
      await db.update('movement_headers', {'version': 4, 'general_concept': 'viejo'}, where: 'local_id = ?', whereArgs: [hid]);
      await LocalMovementEditor(db, now: () => now).updateHeader(hid, generalConcept: ' nuevo ', date: DateTime(2026, 3, 4));
      final h = (await db.query('movement_headers', where: 'local_id = ?', whereArgs: [hid])).single;
      expect((h['general_concept'], h['occurred_at']), ('nuevo', '2026-03-04 10:00:00'));
      final op = await lastOp();
      expect((op['action'], op['ref'], op['base_version'], op['client_id']), ('update', jsonEncode({'serverId': 9000 + banco}), 4, null));
      expect(jsonDecode(op['data']! as String), {'generalConcept': 'nuevo', 'date': '2026-03-04'});
      expect(jsonDecode(op['undo']! as String), [
        {'table': 'movement_headers', 'local_id': hid, 'values': {'general_concept': 'viejo', 'occurred_at': '2026-01-01 10:00:00'}},
      ]);
    });

    test('alta todavía pendiente: ref por clientId y sin baseVersion', () async {
      final m = await writer.createIncome(IncomeDraft(accountLocalId: banco, date: date, concept: 'x', amountCents: 1));
      await LocalMovementEditor(db, now: () => now).updateHeader(m.headerLocalId, generalConcept: 'y');
      final op = await lastOp();
      expect((op['ref'], op['base_version']), (jsonEncode({'clientId': m.clientId}), null));
    });

    test('sin cambios o concepto vacío: VALIDATION_ERROR y no se encola nada', () async {
      final hid = (await db.query('movement_headers', where: 'server_id = ?', whereArgs: [9000 + banco])).single['local_id']! as int;
      await expectRule(() => LocalMovementEditor(db, now: () => now).updateHeader(hid, date: DateTime(2026, 1, 1)), 'VALIDATION_ERROR');
      await expectRule(() => LocalMovementEditor(db, now: () => now).updateHeader(hid, generalConcept: '  '), 'VALIDATION_ERROR');
    });
  });
}
