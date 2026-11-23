// Pantalla "Nuevo ingreso" contra la base local REAL (ffi) y un servidor SIMULADO.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/incomes/presentation/screens/create_income_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  tearDown(() => ServerReachability.markOnline());

  Future<void> abrir(WidgetTester tester) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await pumpScreen(tester, const CreateIncomeScreen(), overrides: localAppOverrides(s, FakeServer()), pushed: true, settle: false);
    await settleIo(tester);
  }

  Future<int> outbox(WidgetTester tester) async => (await tester.runAsync(() => s.count('outbox')))!;

  testWidgets('guarda el ingreso en el celular (concepto por defecto si queda vacío) y vuelve', (tester) async {
    await abrir(tester);
    expect(find.text(l.newIncome), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cuenta-Efectivo')));
    await tester.enterText(find.byType(TextField).first, '250,50');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guardar-ingreso')));
    await settleIo(tester, 10);
    expect(await outbox(tester), 1);
    expect(await tester.runAsync(() => s.balance('Efectivo')), 5000 + 25050);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('sin cuenta o sin monto: muestra el motivo y no guarda', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('guardar-ingreso')));
    await settleIo(tester);
    expect(find.text(l.selectDestinationAccount), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cuenta-Banco')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guardar-ingreso')));
    await settleIo(tester);
    expect(await outbox(tester), 0);
    expect(find.text(l.newIncome), findsOneWidget);
  });
}
