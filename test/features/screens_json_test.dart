// Pantallas reales alimentadas con JSON SIMULADO con la forma de la API: verifica que lo
// que muestra cada pantalla sea exactamente lo que dice el JSON (saldos, totales, %).
// La comparación contra la API real y el celular la hace tools/verify_screens.mjs.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/accounts_admin/presentation/screens/accounts_admin_screen.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/screens/limits_admin_screen.dart';
import 'package:gastos_mobile/features/movements/presentation/screens/movements_screen.dart';

class _FakeApi implements HttpClientAdapter {
  final Map<String, Object> responses;
  _FakeApi(this.responses);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final body = responses[o.path];
    final status = body == null ? 404 : 200;
    return ResponseBody.fromString(
      jsonEncode(body ?? {'statusCode': 404, 'code': 'NOT_FOUND', 'message': 'x'}),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

final accounts = [
  {'id': 1, 'name': 'Banco', 'currency': 'ARS', 'active': true, 'imageUrl': null, 'iconRef': 'banco', 'balanceCents': 444727036, 'movementsCount': 812},
  {'id': 2, 'name': 'Dolar', 'currency': 'USD', 'active': true, 'imageUrl': null, 'iconRef': null, 'balanceCents': 1877000, 'movementsCount': 9},
  {'id': 3, 'name': 'Vieja', 'currency': 'ARS', 'active': false, 'imageUrl': null, 'iconRef': null, 'balanceCents': -1050, 'movementsCount': 1},
];

final budgets = [
  {
    'id': 10,
    'startDate': '2026-10-01',
    'endDate': '2026-10-31',
    'limitCents': 15000000,
    'consumedCents': 16015075,
    'remainingCents': -1015075,
    'percent': 106.76,
    'dueForRenewal': false,
    'categories': [{'id': 7, 'name': 'Comida'}],
    'accounts': [{'id': 1, 'name': 'Banco'}],
  },
  {
    'id': 11,
    'startDate': '2026-09-01',
    'endDate': '2026-09-30',
    'limitCents': 5000000,
    'consumedCents': 1234567,
    'remainingCents': 3765433,
    'percent': 24.69,
    'dueForRenewal': true,
    'categories': [{'id': 8, 'name': 'Auto'}],
    'accounts': [{'id': 1, 'name': 'Banco'}],
  },
];

final movements = {
  'items': [
    {
      'id': 500,
      'type': 2,
      'occurredAt': '2026-10-20 18:05:00',
      'generalConcept': 'Supermercado',
      'accountNames': ['Banco'],
      'amountCents': -2534099,
      'detailsCount': 1,
      'partialDetails': false,
      'details': [
        {
          'id': 900, 'accountId': 1, 'accountName': 'Banco', 'accountActive': true, 'currency': 'ARS',
          'categoryId': 7, 'categoryName': 'Comida', 'categoryRole': null, 'concept': 'Pan', 'observation': null,
          'amountCents': -2534099, 'plu': null, 'unitPriceCents': null, 'imageUrl': null, 'imageNote': null,
        },
      ],
      'fromAccountId': null,
      'toAccountId': null,
    },
  ],
  'total': 1,
  'limit': 50,
  'offset': 0,
  'hasMore': false,
  'filteredTotalCents': 2534099,
};

Future<void> _pump(WidgetTester tester, Widget screen) async {
  FlutterSecureStorage.setMockInitialValues({'is_first_launch_done': 'true'});
  final api = _FakeApi({'/accounts': accounts, '/budgets': budgets, '/movements': movements});
  final client = DioClient(adapter: api)..dio.options.baseUrl = 'http://api.fake/api/v1';
  await tester.pumpWidget(ProviderScope(
    overrides: [dioClientProvider.overrideWithValue(client)],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cuentas: cada saldo coincide con balanceCents del JSON', (tester) async {
    await _pump(tester, const AccountsAdminScreen());
    for (final a in accounts) {
      final expected = Money.format(a['balanceCents']! as int, currency: Currency.parse(a['currency']));
      expect(tester.widget<Text>(find.byKey(ValueKey('saldo-cuenta-${a['id']}'))).data, expected, reason: '${a['name']}');
    }
    expect(find.text('Inactiva'), findsOneWidget);
  });

  testWidgets('Presupuestos: % , consumo, resto y totales vigentes iguales al JSON', (tester) async {
    await _pump(tester, const LimitsAdminScreen());
    for (final b in budgets) {
      final id = b['id'];
      expect(tester.widget<Text>(find.byKey(ValueKey('presupuesto-porcentaje-$id'))).data, Money.percent(b['percent']! as num));
      expect(
        tester.widget<Text>(find.byKey(ValueKey('presupuesto-consumo-$id'))).data,
        '${Money.format(b['consumedCents']! as int)} / ${Money.format(b['limitCents']! as int)}',
      );
    }
    // Vigentes = solo el id 10 (el 11 está vencido).
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-topes'))).data, Money.format(15000000));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-gastado'))).data, Money.format(16015075));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-restante'))).data, Money.format(-1015075));
    expect(find.text('Renovar'), findsOneWidget);
  });

  testWidgets('Movimientos: importe y renglón iguales al JSON', (tester) async {
    await _pump(tester, const MovementsScreen());
    expect(tester.widget<Text>(find.byKey(const ValueKey('mov-importe-500'))).data, Money.format(-2534099));
    await tester.tap(find.text('Supermercado'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('mov-renglon-900'))).data, Money.format(-2534099));
  });
}
