// Pantallas reales. Movimientos se alimenta con JSON SIMULADO con la forma de la API; cuentas
// y límites leen la base local (SQLite REAL, ffi) y deben mostrar exactamente lo que calcula
// su repositorio. La comparación contra la API real la hacen tools/verify_*.mjs en el celular.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/accounts_admin/data/local_accounts_repository.dart';
import 'package:gastos_mobile/features/limits_admin/data/local_budgets_repository.dart';
import 'package:gastos_mobile/features/accounts_admin/presentation/screens/accounts_admin_screen.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/screens/limits_admin_screen.dart';
import 'package:gastos_mobile/features/movements/presentation/screens/movements_screen.dart';
import '../helpers/local_seed.dart';

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

Future<void> _pump(WidgetTester tester, Widget screen, {SeededDb? db}) async {
  FlutterSecureStorage.setMockInitialValues({'is_first_launch_done': 'true'});
  final api = _FakeApi({'/movements': movements});
  final client = DioClient(adapter: api)..dio.options.baseUrl = 'http://api.fake/api/v1';
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioClientProvider.overrideWithValue(client),
      if (db != null) localDatabaseProvider.overrideWithValue(Future.value(db.db)),
    ],
    child: MaterialApp(home: screen),
  ));
  if (db == null) {
    await tester.pumpAndSettle();
    return;
  }
  // Base real: la E/S de SQLite no avanza con el reloj simulado; se la deja correr y se repinta.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

void main() {
  testWidgets('Cuentas: cada saldo coincide con el de la base local', (tester) async {
    final s = (await tester.runAsync(seededDb))!;
    final cuentas = (await tester.runAsync(() => LocalAccountsRepository(s.db).list()))!;
    await _pump(tester, const AccountsAdminScreen(), db: s);
    expect(cuentas, hasLength(4));
    for (final a in cuentas) {
      expect(tester.widget<Text>(find.byKey(ValueKey('saldo-cuenta-${a.id}'))).data, Money.format(a.balanceCents, currency: a.currency),
          reason: a.name);
    }
    expect(find.text('Inactiva'), findsOneWidget);
    await tester.runAsync(s.db.close);
  });

  testWidgets('Presupuestos: %, consumo y totales vigentes iguales a los calculados en la base local', (tester) async {
    final s = (await tester.runAsync(seededDb))!;
    final repo = LocalBudgetsRepository(s.db);
    await tester.runAsync(() async {
      // Un egreso de $ 1.067,51 en Banco/Comida y dos límites: uno vigente y excedido, otro vencido.
      final h = await s.db.insert('movement_headers', {'server_id': 900, 'type': 2, 'occurred_at': '2026-10-10 10:00:00', 'updated_at': 'x'});
      await s.db.insert('movement_details',
          {'server_id': 900, 'header_local_id': h, 'account_local_id': s.accounts['Banco'], 'category_local_id': s.categories['Comida'], 'amount_cents': -106751, 'updated_at': 'x'});
      await repo.create(startDate: '2026-10-01', endDate: '2099-12-31', limitCents: 100000, categoryIds: [s.categories['Comida']!], accountIds: [s.accounts['Banco']!]);
      await repo.create(startDate: '2020-01-01', endDate: '2020-01-31', limitCents: 5000, categoryIds: [s.categories['Super']!], accountIds: [s.accounts['Banco']!]);
    });
    final limites = (await tester.runAsync(repo.list))!;
    await _pump(tester, const LimitsAdminScreen(), db: s);
    for (final b in limites) {
      expect(tester.widget<Text>(find.byKey(ValueKey('presupuesto-porcentaje-${b.id}'))).data, Money.percent(b.percent!));
      expect(tester.widget<Text>(find.byKey(ValueKey('presupuesto-consumo-${b.id}'))).data,
          '${Money.format(b.consumedCents)} / ${Money.format(b.limitCents)}');
    }
    expect(limites.first.percentHundredths, 10675); // 106,751 % truncado
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-topes'))).data, Money.format(100000));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-gastado'))).data, Money.format(106751));
    expect(tester.widget<Text>(find.byKey(const ValueKey('total-restante'))).data, Money.format(-6751));
    expect(find.text('Renovar'), findsOneWidget);
    await tester.runAsync(s.db.close);
  });

  testWidgets('Movimientos: importe y renglón iguales al JSON', (tester) async {
    await _pump(tester, const MovementsScreen());
    expect(tester.widget<Text>(find.byKey(const ValueKey('mov-importe-500'))).data, Money.format(-2534099));
    await tester.tap(find.text('Supermercado'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('mov-renglon-900'))).data, Money.format(-2534099));
  });
}
