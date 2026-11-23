// Pantalla "Límites" contra la base local REAL (ffi): alta con moneda, categorías y cuentas; edición de
// fechas y monto; monto inválido; eliminar con confirmación.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/features/limits_admin/data/local_budgets_repository.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/screens/limits_admin_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/admin_env.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  tearDown(() => CurrentDashboard.id.value = null);

  Future<void> abrir(WidgetTester tester) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await pumpScreen(tester, const LimitsAdminScreen(), settle: false, overrides: [
      ...adminOverrides(s),
      localBudgetsRepositoryProvider.overrideWithValue(Future.value(LocalBudgetsRepository(s.db))),
    ]);
    await settleIo(tester, 10);
  }

  Future<List<Map<String, Object?>>> ops(WidgetTester tester) async => (await tester.runAsync(() => s.db.query('outbox', orderBy: 'seq')))!;

  Future<void> tocar(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> crear(WidgetTester tester, {String monto = '5000', String moneda = 'ARS'}) async {
    await tester.tap(find.byKey(const ValueKey('nuevo-limite')));
    await settleIo(tester);
    await tester.pumpAndSettle();
    await tocar(tester, 'limite-moneda-$moneda');
    await tester.enterText(find.byKey(const ValueKey('limite-monto')), monto);
    await tocar(tester, 'limite-cat-Comida');
    if (moneda == 'ARS') await tocar(tester, 'limite-cuenta-Banco');
    await tocar(tester, 'limite-guardar');
    await settleIo(tester, 10);
  }

  testWidgets('alta: período del mes, categoría y cuenta de la moneda elegida, a la outbox', (tester) async {
    await abrir(tester);
    await crear(tester);
    final op = (await ops(tester)).single;
    expect((op['entity'], op['action']), ('budget', 'create'));
    final data = jsonDecode(op['data']! as String) as Map<String, dynamic>;
    expect(data['limit'], '5000.00');
    expect((data['categoryRefs'] as List).length, 1);
    expect((data['accountRefs'] as List).length, 1);
    expect(find.text(l.budgetCreated), findsOneWidget);
  });

  testWidgets('cambiar a dólares quita las cuentas en pesos elegidas', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nuevo-limite')));
    await settleIo(tester);
    await tester.pumpAndSettle();
    await tocar(tester, 'limite-cuenta-Banco');
    await tocar(tester, 'limite-moneda-USD');
    expect(find.byKey(const ValueKey('limite-cuenta-Banco')), findsNothing);
    expect(find.byKey(const ValueKey('limite-cuenta-Dolares')), findsOneWidget);
    await tocar(tester, 'limite-moneda-ARS');
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('limite-cuenta-Banco'))).selected, isFalse);
  });

  testWidgets('monto inválido: avisa y no encola', (tester) async {
    await abrir(tester);
    await crear(tester, monto: 'abc');
    expect(await ops(tester), isEmpty);
    expect(find.text(l.invalidAmountMax2Decimals), findsOneWidget);
  });

  testWidgets('editar fechas y monto; cancelar no cambia nada; eliminar con confirmación', (tester) async {
    await abrir(tester);
    await crear(tester);
    final id = (await tester.runAsync(() => s.db.query('budgets')))!.single['local_id'];
    await tocar(tester, 'menu-limite-$id');
    await tester.tap(find.text(l.edit).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect((await ops(tester)).length, 1);

    await tocar(tester, 'menu-limite-$id');
    await tester.tap(find.text(l.edit).last);
    await tester.pumpAndSettle();
    await tocar(tester, 'limite-${l.to}');
    await tester.tap(find.text('20'));
    await tester.tap(find.text(MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('limite-monto')), '7000');
    await tocar(tester, 'limite-guardar');
    await settleIo(tester, 10);
    expect(find.text(l.budgetUpdated), findsOneWidget);

    await tocar(tester, 'menu-limite-$id');
    await tester.tap(find.text(l.delete).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-accion')));
    await settleIo(tester, 10);
    expect(find.text(l.budgetDeleted), findsOneWidget);
  });
}
