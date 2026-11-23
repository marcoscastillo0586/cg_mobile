// Pantalla "Transferir dinero" contra la base local REAL (ffi) y un servidor SIMULADO.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/transfers/presentation/screens/create_transfer_screen.dart';
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
    await pumpScreen(tester, const CreateTransferScreen(), overrides: localAppOverrides(s, FakeServer()), pushed: true, settle: false);
    await settleIo(tester);
  }

  Future<void> elegir(WidgetTester tester, int dropdown, String cuenta) async {
    await tester.tap(find.byType(DropdownButton<int>).at(dropdown));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining(cuenta.toUpperCase()).last);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('origen, destino de la misma moneda y monto: guarda el par en el celular y vuelve', (tester) async {
    await abrir(tester);
    expect(find.text(l.transferMoney), findsOneWidget);
    await elegir(tester, 0, 'Banco');
    await elegir(tester, 1, 'Efectivo');
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('guardar-transferencia')));
    await tester.tap(find.byKey(const ValueKey('guardar-transferencia')));
    await settleIo(tester, 10);
    expect(await tester.runAsync(() => s.count('outbox')), 1);
    expect(await tester.runAsync(() => s.balance('Banco')), 100000 - 10000);
    expect(await tester.runAsync(() => s.balance('Efectivo')), 5000 + 10000);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('sin monto muestra el motivo y no guarda; intercambiar origen y destino', (tester) async {
    await abrir(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('guardar-transferencia')));
    await tester.tap(find.byKey(const ValueKey('guardar-transferencia')));
    await settleIo(tester);
    expect(await tester.runAsync(() => s.count('outbox')), 0);
    expect(find.textContaining('mayor a cero'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text(l.transferMoney))).clearSnackBars(); // el aviso taparía el botón
    await tester.pump(const Duration(seconds: 1));
    await elegir(tester, 0, 'Banco');
    await elegir(tester, 1, 'Efectivo');
    await tester.tap(find.byTooltip(l.swapAccounts));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('guardar-transferencia')));
    await tester.tap(find.byKey(const ValueKey('guardar-transferencia')));
    await settleIo(tester, 10);
    expect(await tester.runAsync(() => s.balance('Efectivo')), 5000 - 1000);
  });
}
