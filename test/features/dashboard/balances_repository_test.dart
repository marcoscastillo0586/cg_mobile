// Saldos del dashboard desde SQLite REAL (ffi) + cotización de un servidor SIMULADO.
// No prueba la red real ni el celular.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

class _Rate implements HttpClientAdapter {
  final bool online;
  final bool available;

  /// El servidor no ve saldos en USD y responde 'no aplica' a 1,00.
  final bool notApplicable;
  int calls = 0;
  _Rate({this.online = true, this.available = true, this.notApplicable = false});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls++;
    if (!online) throw DioException.connectionError(requestOptions: o, reason: 'sin red (simulado)');
    return ResponseBody.fromString(
      jsonEncode({
        'until': null,
        'exchangeRate': notApplicable
            ? {'name': 'no aplica', 'sellCents': 100, 'available': true}
            : available
            ? {'name': 'Dólar Blue', 'sellCents': 142550, 'available': true}
            : {'name': 'sin conexión', 'sellCents': 100, 'available': false},
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
  setUp(() async {
    // "Sin conexión" se recuerda 30 s (R2): cada prueba empieza con el servidor alcanzable.
    ServerReachability.markOnline();
    s = await seededDb();
  });
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

  test('sin red y sin cotización previa: USD sin convertir (no hay cotización fija) y el motivo queda informado', () async {
    final b = await repo(_Rate(online: false)).getBalances();
    expect(b.exchangeRate.available, isFalse);
    expect(b.rateError, isA<NetworkException>());
    final usd = b.accounts.firstWhere((a) => a.name == 'Dolares');
    expect(usd.balanceArsCents, isNull);
    expect(b.totalArsCents, 100000 + 5000); // solo ARS
  });

  test('se guarda la cotización recibida y sin red se usa esa, con su fecha', () async {
    await repo(_Rate()).getBalances(); // online: guarda 1.425,50
    final b = await repo(_Rate(online: false)).getBalances();
    expect((b.exchangeRate.available, b.exchangeRate.sellCents, b.exchangeRate.name), (true, 142550, 'Dólar Blue'));
    expect(b.exchangeRate.receivedAt, isNotNull);
    expect(b.exchangeRate.isStale, isTrue);
    expect(b.accounts.firstWhere((a) => a.name == 'Dolares').balanceArsCents, 14255000);
    expect(b.rateError, isA<NetworkException>());
  });

  test('si el servidor responde su contingencia (dolarapi caído) no se guarda como cotización real', () async {
    final b = await repo(_Rate(available: false)).getBalances();
    expect(b.exchangeRate.available, isFalse);
    expect((await s.db.query('sync_state')).single['rate_sell_cents'], isNull);
    expect(b.accounts.firstWhere((a) => a.name == 'Dolares').balanceArsCents, isNull);
  });

  test('sin cuentas en USD no se consulta la cotización', () async {
    await s.db.update('accounts', {'active': 0}, where: 'local_id = ?', whereArgs: [s.accounts['Dolares']]);
    final rate = _Rate();
    final b = await repo(rate).getBalances();
    expect(rate.calls, 0);
    expect(b.exchangeRate.isNotApplicable, isTrue);
  });

  test("'no aplica' del servidor (no ve saldos en USD) no es una cotización: no se guarda ni convierte a 1,00", () async {
    final sinPrevia = await repo(_Rate(notApplicable: true)).getBalances();
    expect((await s.db.query('sync_state')).single['rate_sell_cents'], isNull);
    expect(sinPrevia.accounts.firstWhere((a) => a.name == 'Dolares').balanceArsCents, isNull, reason: 'no a 1,00');

    await repo(_Rate()).getBalances(); // guarda 1.425,50
    final conPrevia = await repo(_Rate(notApplicable: true)).getBalances();
    expect((conPrevia.exchangeRate.sellCents, conPrevia.exchangeRate.isStale), (142550, true));
    expect(conPrevia.accounts.firstWhere((a) => a.name == 'Dolares').balanceArsCents, 14255000);
    expect((await s.db.query('sync_state')).single['rate_sell_cents'], 142550);
  });

  test('toArsCents redondea igual que ExchangeRateService (mitad lejos de cero, también negativos)', () {
    expect(BalancesRepository.toArsCents(1, 150), 2); // 1,50 → 2
    expect(BalancesRepository.toArsCents(1, 149), 1); // 1,49 → 1
    expect(BalancesRepository.toArsCents(-1, 150), -2);
    expect(BalancesRepository.toArsCents(-1, 149), -1);
    expect(BalancesRepository.toArsCents(123456789, 142550), 175987652720); // = 175987652719,5 → …720 (fórmula del servidor en Node)
  });
}
