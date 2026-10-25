// Ediciones y borrados sin conexión contra SQLite REAL (ffi). No prueba la red ni el servidor.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/core/sync/push_service.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_editor.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late LocalMovementEditor editor;
  // Egreso sincronizado (server 500) con 2 renglones en Banco y una transferencia (server 600) Banco → Efectivo.
  late int compra, bife, pan, transfer;

  Future<int> header(int serverId, int type, String concept) => s.db.insert('movement_headers', {
        'server_id': serverId, 'type': type, 'occurred_at': '2026-10-01 12:30:00', 'general_concept': concept, 'version': 3, 'updated_at': 'x',
      });
  Future<int> detail(int serverId, int headerId, String account, int cents, {String? category, String? concept}) => s.db.insert('movement_details', {
        'server_id': serverId, 'header_local_id': headerId, 'account_local_id': s.accounts[account], 'category_local_id': category == null ? null : s.categories[category],
        'concept': concept, 'amount_cents': cents, 'updated_at': 'x',
      });

  setUp(() async {
    s = await seededDb();
    editor = await s.editor;
    compra = await header(500, 2, 'Carnicería');
    bife = await detail(501, compra, 'Banco', -3000, category: 'Comida', concept: 'BIFE');
    pan = await detail(502, compra, 'Banco', -1000, category: 'Comida', concept: 'PAN');
    transfer = await header(600, 3, 'Transferencia desde BANCO hacia EFECTIVO');
    await detail(601, transfer, 'Efectivo', 2000, category: 'Transferencia', concept: 't');
    await detail(602, transfer, 'Banco', -2000, category: 'Transferencia', concept: 't');
  });
  tearDown(() => s.db.close());

  Future<Map<String, Object?>> lastOp() async => (await s.db.query('outbox', orderBy: 'seq DESC', limit: 1)).single;
  Future<void> rule(Future<Object?> Function() f, String code) async {
    final ops = await s.count('outbox');
    await expectLater(f(), throwsA(isA<ValidationFailure>().having((e) => e.code, 'code', code)));
    expect(await s.count('outbox'), ops, reason: 'no debe encolarse nada');
  }

  Future<void> revertLast() async {
    final op = await lastOp();
    await s.db.transaction((txn) => PushService.revert(txn, op));
  }

  test('carga el comprobante con sus renglones desde la base local', () async {
    final m = (await editor.loadByServerId(500))!;
    expect((m.type, m.generalConcept, m.synced, m.canDeleteDetail), (2, 'Carnicería', true, true));
    expect(m.details.map((d) => (d.concept, d.amountCents, d.accountName, d.categoryName)), [
      ('BIFE', -3000, 'Banco', 'Comida'),
      ('PAN', -1000, 'Banco', 'Comida'),
    ]);
    final t = (await editor.loadByServerId(600))!;
    expect((t.isTransfer, t.canDeleteDetail, t.transferFrom!.accountName, t.transferTo!.accountName), (true, false, 'Banco', 'Efectivo'));
  });

  group('renglón', () {
    test('monto de egreso: signo negativo local, decimal positivo en la operación, ref por serverId sin baseVersion', () async {
      await editor.updateDetail(bife, amountCents: 3550, concept: 'BIFE ANCHO');
      final d = (await s.db.query('movement_details', where: 'local_id = ?', whereArgs: [bife])).single;
      expect((d['amount_cents'], d['concept']), (-3550, 'BIFE ANCHO'));
      final op = await lastOp();
      expect((op['entity'], op['action'], op['ref'], op['base_version']), ('movement_detail', 'update', jsonEncode({'serverId': 501}), null));
      expect(jsonDecode(op['data']! as String), {'concept': 'BIFE ANCHO', 'amount': '35.50'});
      await revertLast();
      final back = (await s.db.query('movement_details', where: 'local_id = ?', whereArgs: [bife])).single;
      expect((back['amount_cents'], back['concept']), (-3000, 'BIFE'));
    });

    test('puede dejar la cuenta en negativo (regla del usuario: se avisa en la pantalla)', () async {
      final before = await s.balance('Banco');
      await editor.updateDetail(bife, amountCents: 999999);
      expect(await s.balance('Banco'), before + 3000 - 999999);
      expect(await s.balance('Banco'), lessThan(0));
    });

    test('categorías: reservada en egreso o cambio en ingreso se rechazan', () async {
      await rule(() => editor.updateDetail(bife, categoryLocalId: s.categories['Transferencia']), 'RESERVED_CATEGORY');
      final ingreso = (await s.db.query('movement_details', where: 'server_id = 101')).single['local_id']! as int;
      await rule(() => editor.updateDetail(ingreso, categoryLocalId: s.categories['Comida']), 'RESERVED_CATEGORY');
      await editor.updateDetail(bife, categoryLocalId: s.categories['Super']);
      expect(jsonDecode((await lastOp())['data']! as String), {'categoryRef': {'serverId': 6}}); // Super
    });

    test('borrar: solo si hay más de uno; el único renglón queda bloqueado', () async {
      await editor.deleteDetail(pan);
      expect(await s.count('movement_details', 'header_local_id = $compra AND deleted = 0'), 1);
      expect(((await lastOp())['entity'], (await lastOp())['action'], (await lastOp())['ref']), ('movement_detail', 'delete', jsonEncode({'serverId': 502})));
      await rule(() => editor.deleteDetail(bife), 'LAST_DETAIL');
      await revertLast();
      expect(await s.count('movement_details', 'header_local_id = $compra AND deleted = 0'), 2);
    });

    test('transferencia: sus renglones no se editan ni se borran por separado', () async {
      final t = (await editor.loadByServerId(600))!;
      await rule(() => editor.updateDetail(t.details.first.localId, amountCents: 1), 'TRANSFER_EDIT');
      await rule(() => editor.deleteDetail(t.details.first.localId), 'TRANSFER_EDIT');
    });

    test('alta todavía no enviada: no se edita por renglón (no tiene serverId)', () async {
      final m = await (await s.writer).createExpense(ExpenseDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 1), generalConcept: 'x',
          lines: [ExpenseLine(concept: 'a', categoryLocalId: s.categories['Comida']!, amountCents: 1)]));
      final d = (await editor.load(m.headerLocalId))!.details.single;
      await rule(() => editor.updateDetail(d.localId, amountCents: 2), 'VALIDATION_ERROR');
    });
  });

  group('encabezado', () {
    test('cambiar la cuenta mueve todos los renglones; deshacer vuelve a la original', () async {
      await editor.updateHeader(compra, accountLocalId: s.accounts['Efectivo']);
      expect(await s.count('movement_details', 'header_local_id = $compra AND account_local_id = ${s.accounts['Efectivo']}'), 2);
      final op = await lastOp();
      expect(op['base_version'], 3);
      expect(jsonDecode(op['data']! as String), {'accountRef': {'serverId': 2}});
      await revertLast();
      expect(await s.count('movement_details', 'header_local_id = $compra AND account_local_id = ${s.accounts['Banco']}'), 2);
    });

    test('otra moneda o transferencia: rechazado', () async {
      await rule(() => editor.updateHeader(compra, accountLocalId: s.accounts['Dolares']), 'CURRENCY_MISMATCH');
      await rule(() => editor.updateHeader(transfer, accountLocalId: s.accounts['Efectivo']), 'TRANSFER_EDIT');
    });
  });

  group('transferencia', () {
    test('reemplaza el par; deshacer lo restaura', () async {
      await editor.updateTransfer(transfer, fromLocalId: s.accounts['Banco']!, toLocalId: s.accounts['Efectivo']!, amountCents: 5000);
      expect((await s.balance('Banco'), await s.balance('Efectivo')), (100000 - 3000 - 1000 - 5000, 5000 + 5000));
      final op = await lastOp();
      expect(jsonDecode(op['data']! as String), {'transfer': {'fromRef': {'serverId': 1}, 'toRef': {'serverId': 2}, 'amount': '50.00'}});
      expect(op['base_version'], 3);
      await revertLast();
      expect((await s.balance('Banco'), await s.balance('Efectivo')), (100000 - 3000 - 1000 - 2000, 5000 + 2000));
    });

    test('dejaría el origen en negativo: el celular no lo bloquea (R2: decide el servidor al enviarla)', () async {
      // Sin la transferencia actual Efectivo tiene 5000; como origen manda 9001 → -4001 y queda en la cola.
      await editor.updateTransfer(transfer, fromLocalId: s.accounts['Efectivo']!, toLocalId: s.accounts['Banco']!, amountCents: 5001 + 4000);
      expect(await s.balance('Efectivo'), 5000 - 9001);
      expect((await lastOp())['status'], 'pending');
    });
  });

  group('comprobante', () {
    test('sincronizado: se marca eliminado (no cuenta en el saldo) y se encola delete con baseVersion', () async {
      final before = await s.balance('Banco');
      await editor.deleteMovement(compra);
      expect(await s.balance('Banco'), before + 4000);
      final op = await lastOp();
      expect((op['entity'], op['action'], op['ref'], op['base_version']), ('movement', 'delete', jsonEncode({'serverId': 500}), 3));
      await revertLast();
      expect(await s.balance('Banco'), before);
    });

    test('alta nunca enviada: se quita del celular con su operación (no hay nada que avisar al servidor)', () async {
      final m = await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 1), concept: 'x', amountCents: 1));
      expect(await editor.deleteMovement(m.headerLocalId), isNull);
      expect(await s.count('outbox'), 0);
      expect(await s.count('movement_headers', "client_id = '${m.clientId}'"), 0);
    });

    test('alta ya intentada: se encola delete por clientId (el servidor la resuelve)', () async {
      final m = await (await s.writer).createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 1), concept: 'x', amountCents: 1));
      await s.db.update('outbox', {'attempts': 1});
      await editor.deleteMovement(m.headerLocalId);
      final op = await lastOp();
      expect((op['action'], op['ref'], op['base_version']), ('delete', jsonEncode({'clientId': m.clientId}), null));
    });
  });
}
