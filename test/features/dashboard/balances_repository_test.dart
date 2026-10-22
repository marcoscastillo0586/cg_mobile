// Saldos del dashboard desde SQLite REAL (ffi) + cotización de un servidor SIMULADO.
// No prueba la red real ni el celular.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

class _Rate implements HttpClientAdapter {
  final bool online;
  int calls = 0;
  _Rate({this.online = true});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls++;
    if (!online) throw DioException.connectionError(requestOptions: o, reason: 'sin red (simulado)');
    return ResponseBody.fromString(
      jsonEncode({
        'until': null,
        'exchangeRate': {'name': 'Dólar Blue', 'sellCents': 142550, 'available': true},
        'totalArsCents': 0,
        'accounts': <Object>[],
      }),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late SeededDb s;
  setUp(() async => s = await seededDb());
  tearDown(() => s.db.close());

  BalancesRepository repo(_Rate rate) =>
      BalancesRepository(Future.value(s.db), DioClient(adapter: rate)..dio.options.baseUrl = 'http://api.fake/api/v1');

  test('cuentas activas con saldo ≠ 0, por nombre; incluye lo pendiente de enviar', () async {
    await (await s.writer).createExpense(ExpenseDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21),
        generalConcept: 'x', lines: [ExpenseLine(concept: 'a', categoryLocalId: s.categories['Comida']!, amountCents: 2500)]));
    final b = await repo(_Rate()).getBalances();
    expect(b.accounts.map((a) => (a.name, a.balanceCents)), [('Banco', 97500), ('Dolares', 10000), ('Efectivo', 5000)]);
    // US$ 100,00 a 1.425,50 = $ 142.550,00
    expect(b.accounts[1].balanceArsCents, 14255000);
    expect(b.totalArsCents, 97500 + 14255000 + 5000);
    expect(b.exchangeRate.name, 'Dólar Blue');
    expect(b.rateError, isNull);
  });

  test('fecha de corte: incluye todo ese día y excluye lo posterior', () async {
    final w = await s.writer;
    await w.createIncome(IncomeDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 10, 21), concept: 'x', amountCents: 1));
    expect((await repo(_Rate()).getBalances(until: '2026-10-20')).accounts.first.balanceCents, 100000);
    expect((await repo(_Rate()).getBalances(until: '2026-10-21')).accounts.first.balanceCents, 100001);
  });

  test('sin red: contingencia 1,00 y el motivo queda informado (no se inventa una cotización)', () async {
    final b = await repo(_Rate(online: false)).getBalances();
    expect(b.exchangeRate.available, isFalse);
    expect(b.exchangeRate.sellCents, 100);
    expect(b.rateError, isA<NetworkException>());
    expect(b.accounts.firstWhere((a) => a.name == 'Dolares').balanceArsCents, 10000);
  });

  test('sin cuentas en USD no se consulta la cotización', () async {
    await s.db.update('accounts', {'active': 0}, where: 'local_id = ?', whereArgs: [s.accounts['Dolares']]);
    final rate = _Rate();
    final b = await repo(rate).getBalances();
    expect(rate.calls, 0);
    expect(b.exchangeRate.name, 'no aplica');
  });

  test('toArsCents redondea igual que ExchangeRateService (mitad lejos de cero, también negativos)', () {
    expect(BalancesRepository.toArsCents(1, 150), 2); // 1,50 → 2
    expect(BalancesRepository.toArsCents(1, 149), 1); // 1,49 → 1
    expect(BalancesRepository.toArsCents(-1, 150), -2);
    expect(BalancesRepository.toArsCents(-1, 149), -1);
    expect(BalancesRepository.toArsCents(123456789, 142550), 175987652720); // = 175987652719,5 → …720 (fórmula del servidor en Node)
  });
}
