// Pantalla "Nuevo egreso" contra la base local REAL (ffi) y un servidor SIMULADO.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/expenses/presentation/screens/create_expense_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;
  late FakeServer server;

  setUp(() async => server = FakeServer());
  tearDown(() => ServerReachability.markOnline());

  Future<void> abrir(WidgetTester tester) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await pumpScreen(tester, const CreateExpenseScreen(), overrides: localAppOverrides(s, server), pushed: true, settle: false);
    await settleIo(tester);
  }

  Future<void> completar(WidgetTester tester, {required String cuenta, required String monto}) async {
    await tester.tap(find.byKey(ValueKey('cuenta-$cuenta')));
    await tester.pump();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Kiosco');
    await tester.enterText(campos.at(1), 'Alfajor');
    await tester.enterText(campos.at(2), monto);
    await tester.pump();
  }

  Future<int> outbox(WidgetTester tester) async => (await tester.runAsync(() => s.count('outbox')))!;

  testWidgets('muestra cuentas activas y el total; sin concepto general no registra y lo marca', (tester) async {
    await abrir(tester);
    expect(find.text(l.newExpense), findsOneWidget);
    for (final c in ['Banco', 'Efectivo', 'Dolares']) {
      expect(find.byKey(ValueKey('cuenta-$c')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('cuenta-Cerrada')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('guardar-egreso')));
    await tester.pump();
    expect(find.text(l.fillConceptField), findsWidgets);
    expect(await outbox(tester), 0);
  });

  testWidgets('con fondos: guarda en el celular, lo encola y vuelve', (tester) async {
    await abrir(tester);
    await completar(tester, cuenta: 'Banco', monto: '150');
    await tester.tap(find.byKey(const ValueKey('guardar-egreso')));
    await settleIo(tester, 10);
    expect(await outbox(tester), 1);
    expect(find.text('inicio'), findsOneWidget);
    expect(await tester.runAsync(() => s.balance('Banco')), 100000 - 15000);
  });

  testWidgets('sin fondos y con conexión: pide confirmar; cancelar no guarda, confirmar sí', (tester) async {
    await abrir(tester);
    ServerReachability.markOnline(); // el servidor simulado no tiene /sync: al abrir quedó "sin conexión"
    await completar(tester, cuenta: 'Efectivo', monto: '80');
    await tester.tap(find.byKey(const ValueKey('guardar-egreso')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l.balanceWillNegative), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await outbox(tester), 0);
    await tester.tap(find.byKey(const ValueKey('guardar-egreso')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('guardar-igual')));
    await settleIo(tester, 10);
    expect(await outbox(tester), 1);
    expect(await tester.runAsync(() => s.balance('Efectivo')), 5000 - 8000);
  });

  testWidgets('sin conexión: guarda sin preguntar por los fondos', (tester) async {
    await abrir(tester);
    ServerReachability.markOffline();
    await completar(tester, cuenta: 'Efectivo', monto: '80');
    await tester.tap(find.byKey(const ValueKey('guardar-egreso')));
    await settleIo(tester, 10);
    expect(find.text(l.balanceWillNegative), findsNothing);
    expect(await outbox(tester), 1);
  });

  testWidgets('"Escanear ticket" sin servidor avisa que no está disponible', (tester) async {
    await abrir(tester);
    await tester.tap(find.text(l.scanReceipt).first);
    await settleIo(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('escanear-sin-conexion')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('escanear-sin-conexion')), matching: find.byType(TextButton)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('escanear-sin-conexion')), findsNothing);
  });
}
