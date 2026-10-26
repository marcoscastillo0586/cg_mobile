// Saldos del dashboard desde SQLite REAL (ffi). Sin servidor: no hay cotización ni conversión entre
// monedas; cada saldo va en la moneda de su cuenta. No prueba la red ni el celular.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  setUp(() async => s = await seededDb());
  tearDown(() => s.db.close());

  BalancesRepository repo() => BalancesRepository(Future.value(s.db));

  test('cuentas activas con saldo ≠ 0, por nombre, en su moneda; incluye lo pendiente de enviar', () async {
    await (await s.writer).createExpense(ExpenseDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21),
        generalConcept: 'x', lines: [ExpenseLine(concept: 'a', categoryLocalId: s.categories['Comida']!, amountCents: 2500)]));
    final b = await repo().getBalances();
    expect(b.accounts.map((a) => (a.name, a.currency, a.balanceCents)), [
      ('Banco', Currency.ars, 97500),
      ('Dolares', Currency.usd, 10000), // US$ 100,00 sin convertir
      ('Efectivo', Currency.ars, 5000),
    ]);
    expect(b.currencies, {Currency.ars, Currency.usd});
  });

  test('el historial de cada cuenta se abre con su id del servidor', () async {
    final b = await repo().getBalances();
    final banco = b.accounts.firstWhere((a) => a.name == 'Banco');
    expect(banco.id, s.accounts['Banco']);
    expect(banco.serverId, isNotNull);
  });

  test('fecha de corte: incluye todo ese día y excluye lo posterior', () async {
    final w = await s.writer;
    await w.createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
    expect((await repo().getBalances(until: '2026-10-20')).accounts.first.balanceCents, 100000);
    expect((await repo().getBalances(until: '2026-10-21')).accounts.first.balanceCents, 100001);
  });

  test('sin cuentas en una moneda, esa moneda no figura (su total se oculta)', () async {
    await s.db.update('accounts', {'active': 0}, where: 'local_id = ?', whereArgs: [s.accounts['Dolares']]);
    final b = await repo().getBalances();
    expect(b.currencies, {Currency.ars});
  });
}
