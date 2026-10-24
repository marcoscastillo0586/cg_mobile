// Acciones de "Pendientes y rechazados" contra SQLite REAL (ffi). Los estados del servidor se
// simulan escribiendo server_result como lo deja PushService; no hay red.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/core/sync/outbox_repository.dart';
import 'package:gastos_mobile/core/sync/push_service.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late OutboxRepository repo;
  setUp(() async {
    s = await seededDb();
    repo = OutboxRepository(s.db);
  });
  tearDown(() => s.db.close());

  Future<SavedMovement> gasto(int cents) async => (await s.writer).createExpense(ExpenseDraft(
      accountLocalId: s.accounts['Efectivo']!, date: DateTime(2026, 10, 21), generalConcept: 'kiosco',
      lines: [ExpenseLine(concept: 'pan', categoryLocalId: s.categories['Comida']!, amountCents: cents)]));

  Future<int> seqOf(String opId) async => (await s.db.query('outbox', where: 'op_id = ?', whereArgs: [opId])).single['seq']! as int;

  /// Simula lo que deja PushService ante un rechazo.
  Future<void> reject(String opId, String code) async {
    final op = (await s.db.query('outbox', where: 'op_id = ?', whereArgs: [opId])).single;
    await s.db.transaction((txn) async {
      await PushService.revert(txn, op);
      await txn.update('outbox', {
        'status': 'rejected', 'attempts': 1,
        'server_result': jsonEncode({'status': 'rejected', 'error': {'code': code, 'message': 'motivo'}}),
      }, where: 'op_id = ?', whereArgs: [opId]);
    });
  }

  test('lista lo no aplicado con descripción y motivo', () async {
    final m = await gasto(1500);
    await reject(m.opId, 'ACCOUNT_INACTIVE');
    final e = (await repo.unresolved()).single;
    expect((e.status, e.errorCode, e.canCorrect, e.canDiscard), ('rejected', 'ACCOUNT_INACTIVE', true, true));
    expect(e.description, contains('Egreso "kiosco"'));
    expect(e.description, contains(r'$ 15,00'));
    expect(e.description, contains('EFECTIVO'));
  });

  test('descartar un rechazado borra el comprobante local; el saldo queda como el del servidor', () async {
    final m = await gasto(1500);
    await reject(m.opId, 'ACCOUNT_INACTIVE');
    expect(await s.balance('Efectivo'), 5000); // revertido por el rechazo
    await repo.discard(await seqOf(m.opId));
    expect(await s.count('outbox'), 0);
    expect(await s.count('movement_headers', "client_id = '${m.clientId}'"), 0);
    expect(await s.balance('Efectivo'), 5000);
  });

  test('descartar un pendiente nunca enviado revierte el saldo; uno ya intentado no se puede', () async {
    final a = await gasto(1000);
    expect(await s.balance('Efectivo'), 4000);
    await repo.discard(await seqOf(a.opId));
    expect(await s.balance('Efectivo'), 5000);

    final b = await gasto(1000);
    await s.db.update('outbox', {'attempts': 1}, where: 'op_id = ?', whereArgs: [b.opId]);
    await expectLater(repo.discard(await seqOf(b.opId)), throwsA(isA<ValidationFailure>()));
    expect(await s.balance('Efectivo'), 4000);
  });

  test('corregir: los datos vuelven al formulario y guardar reemplaza el rechazado en una transacción', () async {
    final m = await gasto(1500);
    await reject(m.opId, 'ACCOUNT_INACTIVE');
    final seq = await seqOf(m.opId);
    final c = await repo.correction(seq);
    expect((c.type, c.concept, c.accountLocalId), (2, 'kiosco', s.accounts['Efectivo']));
    expect(c.lines.map((l) => (l.concept, l.categoryLocalId, l.amountCents)), [('pan', s.categories['Comida'], 1500)]);

    final fixed = await (await s.writer).createExpense(
      ExpenseDraft(accountLocalId: c.accountLocalId!, date: c.date, generalConcept: c.concept,
          lines: [ExpenseLine(concept: 'pan', categoryLocalId: c.lines.single.categoryLocalId!, amountCents: 1000)]),
      replacingSeq: seq,
    );
    final ops = await s.db.query('outbox');
    expect(ops.map((o) => (o['op_id'], o['status'])), [(fixed.opId, 'pending')]);
    expect(fixed.opId, isNot(m.opId));
    expect(await s.count('movement_headers', "client_id = '${m.clientId}'"), 0);
    expect(await s.balance('Efectivo'), 4000);
  });

  test('si la corrección no pasa las reglas, el rechazado original queda intacto', () async {
    final m = await gasto(1500);
    await reject(m.opId, 'ACCOUNT_INACTIVE');
    final seq = await seqOf(m.opId);
    await expectLater(
      (await s.writer).createExpense(
          ExpenseDraft(accountLocalId: s.accounts['Efectivo']!, date: DateTime(2026, 10, 21), generalConcept: 'x',
              lines: [ExpenseLine(concept: 'pan', categoryLocalId: s.categories['Transferencia']!, amountCents: 100)]),
          replacingSeq: seq),
      throwsA(isA<ValidationFailure>()),
    );
    expect((await s.db.query('outbox')).single['status'], 'rejected');
  });

  test('conflicto: reintentar con mis cambios reaplica el dato local y reencola con baseVersion del servidor', () async {
    final hid = (await s.db.query('movement_headers', where: 'server_id = 101')).single['local_id']! as int;
    await s.db.update('movement_headers', {'version': 1, 'general_concept': 'original'}, where: 'local_id = ?', whereArgs: [hid]);
    final opId = await (await s.editor).updateHeader(hid, generalConcept: 'mío');
    // Lo que deja PushService: conflicto, current aplicado (gana el servidor).
    await s.db.update('movement_headers', {'general_concept': 'de la web', 'version': 2}, where: 'local_id = ?', whereArgs: [hid]);
    await s.db.update('outbox', {
      'status': 'conflict', 'attempts': 1,
      'server_result': jsonEncode({'status': 'conflict', 'serverId': 101, 'version': 2, 'error': {'code': 'VERSION_CONFLICT', 'message': 'x'}}),
    }, where: 'op_id = ?', whereArgs: [opId]);

    final e = (await repo.unresolved()).single;
    expect((e.canRetryMine, e.canDiscard, e.canCorrect), (true, true, false));
    await repo.retryMine(e.seq);
    final op = (await s.db.query('outbox')).single;
    expect((op['status'], op['base_version'], op['op_id'] == opId), ('pending', 2, false));
    expect(jsonDecode(op['data']! as String), {'generalConcept': 'mío'});
    expect((await s.db.query('movement_headers', where: 'local_id = ?', whereArgs: [hid])).single['general_concept'], 'mío');
  });

  test('conflicto: quedarme con la del servidor quita la operación y deja el dato del servidor', () async {
    final hid = (await s.db.query('movement_headers', where: 'server_id = 101')).single['local_id']! as int;
    final opId = await (await s.editor).updateHeader(hid, generalConcept: 'mío');
    await s.db.update('movement_headers', {'general_concept': 'de la web'}, where: 'local_id = ?', whereArgs: [hid]);
    await s.db.update('outbox', {'status': 'conflict', 'attempts': 1, 'server_result': jsonEncode({'status': 'conflict', 'serverId': 101, 'version': 2})},
        where: 'op_id = ?', whereArgs: [opId]);
    await repo.discard(await seqOf(opId));
    expect(await s.count('outbox'), 0);
    expect((await s.db.query('movement_headers', where: 'local_id = ?', whereArgs: [hid])).single['general_concept'], 'de la web');
  });
}
