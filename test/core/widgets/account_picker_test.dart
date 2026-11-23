// Selector de cuentas y aviso de fondos de los formularios.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/widgets/account_picker.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) => tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ));

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  const banco = LocalAccount(localId: 1, serverId: 1, clientId: null, name: 'Banco', currency: Currency.ars, active: true, balanceCents: 150000, iconRef: '01', imageUrl: null);
  const tarjeta = LocalAccount(localId: 2, serverId: 2, clientId: null, name: 'Tarjeta', currency: Currency.ars, active: true, balanceCents: -2500, iconRef: '02', imageUrl: null);

  testWidgets('sin cuentas: avisa que hay que sincronizar', (tester) async {
    await _pump(tester, AccountPicker(cuentas: const [], selectedId: null, onSelect: (_) {}));
    expect(find.text(l.noAccountsPhoneSyncWhile), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('cuentas con su saldo; tocar elige y la elegida lleva el check ($brightness)', (tester) async {
      int? elegida;
      await _pump(tester, AccountPicker(cuentas: const [banco, tarjeta], selectedId: 2, onSelect: (id) => elegida = id), brightness: brightness);
      expect(find.text('BANCO'), findsOneWidget);
      expect(find.text(Money.format(150000)), findsOneWidget);
      expect(find.text(Money.format(-2500)), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cuenta-Banco')));
      expect(elegida, 1);
    });
  }

  testWidgets('aviso de fondos: transferencia bloquea con el disponible; egreso avisa cómo queda la cuenta', (tester) async {
    await _pump(tester, const FundsWarning(cuenta: banco, amountCents: 200000, blocking: true));
    expect(find.text(l.notEnoughBalanceTransferAvailable(Money.format(200000), 'BANCO', Money.format(150000))), findsOneWidget);
    await _pump(tester, const FundsWarning(cuenta: banco, amountCents: 200000));
    expect(find.text(negativeBalanceText(banco, 200000, l)), findsOneWidget);
    expect(negativeBalanceText(banco, 200000, l), contains(Money.format(-50000)));
  });
}
