// Nombre del mes en el idioma de la app, con mayúscula inicial y sin punto en la forma corta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/l10n/l10n.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  Future<List<String>> names(WidgetTester tester, Locale locale) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    return [ctx.monthName(1), ctx.monthName(9, short: true)];
  }

  testWidgets('español e inglés', (tester) async {
    expect(await names(tester, const Locale('es')), ['Enero', 'Sept']);
    expect(await names(tester, const Locale('en')), ['January', 'Sep']);
  });
}

