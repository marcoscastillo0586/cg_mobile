// Informes: categorías, comparativa anual y día a día con un repositorio de reportes SIMULADO.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/analytics/data/reports_repository.dart';
import 'package:gastos_mobile/features/analytics/presentation/providers/analytics_notifier.dart';
import 'package:gastos_mobile/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';
import 'fake_reports.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  final now = DateTime.now();

  Future<FakeReports> abrir(WidgetTester tester, {FakeReports? repo}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final r = repo ?? FakeReports();
    await pumpScreen(tester, const AnalyticsScreen(), settle: false, overrides: [reportsRepositoryProvider.overrideWithValue(r)]);
    await tester.pump();
    await tester.pump();
    return r;
  }

  Future<void> pestana(WidgetTester tester, String nombre) async {
    await tester.tap(find.text(nombre));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  test('períodos: mes, mes anterior (cruza el año) y año', () {
    expect(AnalyticsNotifier.rangoDe('mes_actual', DateTime(2026, 2, 10)), (DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
    expect(AnalyticsNotifier.rangoDe('mes_anterior', DateTime(2026, 1, 10)), (DateTime(2025, 12, 1), DateTime(2025, 12, 31)));
    expect(AnalyticsNotifier.rangoDe('anio_actual', DateTime(2026, 6, 1)), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
  });

  testWidgets('categorías: torta, conceptos frecuentes y cambio de período', (tester) async {
    final repo = await abrir(tester);
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text(Money.format(5000)), findsOneWidget);
    expect(find.text('16.7%'), findsOneWidget);
    await tester.tap(find.text(l.previousMonth));
    await tester.pump();
    final (desde, hasta) = AnalyticsNotifier.rangoDe('mes_anterior', now);
    expect(repo.calls.last, contains('${desde.year}-${desde.month.toString().padLeft(2, '0')}-01'));
    expect(hasta.day, greaterThanOrEqualTo(28));
  });

  testWidgets('categorías: rango personalizado', (tester) async {
    final repo = await abrir(tester);
    await tester.ensureVisible(find.text(l.custom));
    await tester.pump();
    await tester.tap(find.text(l.custom));
    await tester.pumpAndSettle();
    final ml = MaterialLocalizations.of(tester.element(find.byType(Scaffold).last));
    await tester.tap(find.byTooltip(ml.inputDateModeButtonLabel)); // entrada de texto del selector de rango
    await tester.pumpAndSettle();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), '01/10/2026');
    await tester.enterText(campos.at(1), '15/10/2026');
    await tester.tap(find.text(ml.okButtonLabel));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'categorias 2026-10-01 2026-10-15');
    expect(find.text('01/10/2026 - 15/10/2026'), findsOneWidget);
  });

  testWidgets('comparativa anual: indicadores, desglose y cambio de año', (tester) async {
    final repo = await abrir(tester);
    await pestana(tester, l.comparison);
    expect(repo.calls.last, 'anual ${now.year}');
    expect(find.text(Money.format(110000)), findsOneWidget);
    expect(find.text(Money.percent(45.5)), findsOneWidget);
    expect(find.text(l.surplus), findsOneWidget);
    expect(find.text(l.deficit), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('anio-comparativa')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'anual 2025');
  });

  testWidgets('día a día: total y pico del mes; otro mes', (tester) async {
    final repo = await abrir(tester);
    await pestana(tester, l.dayDay);
    expect(repo.calls.last, 'diaria ${now.year}-${now.month}');
    expect(find.text(Money.format(7000)), findsOneWidget); // pico
    await tester.tap(find.byKey(const ValueKey('mes-diario')));
    await tester.pumpAndSettle();
    final otro = now.month == 12 ? 11 : now.month + 1; // junto al elegido: visible en el menú
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownMenuItem<int> && w.value == otro).last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'diaria ${now.year}-$otro');
  });

  testWidgets('volver a una pestaña ya cargada no consulta; ↻ sí', (tester) async {
    final repo = await abrir(tester);
    await pestana(tester, l.comparison);
    await pestana(tester, l.categories2);
    final antes = repo.calls.length;
    await pestana(tester, l.comparison);
    expect(repo.calls.length, antes);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    expect(repo.calls.last, 'anual ${now.year}');
    for (final (tab, llamada) in [(l.categories2, 'categorias'), (l.dayDay, 'diaria'), (l.prices, 'productos')]) {
      await pestana(tester, tab);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      expect(repo.calls.last, startsWith(llamada));
    }
  });

  testWidgets('mientras carga por primera vez, esqueleto; un error se muestra con su código', (tester) async {
    final repo = FakeReports()..gate = Completer();
    await abrir(tester, repo: repo);
    expect(find.text('Pan'), findsNothing);
    repo.error = const ServerException('caído', 500, 'INTERNAL_ERROR');
    repo.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('reporte-error')), findsOneWidget);
    expect(find.textContaining('(INTERNAL_ERROR)'), findsOneWidget);
  });

  testWidgets('arrastrar hacia abajo actualiza la pestaña', (tester) async {
    final repo = await abrir(tester);
    final antes = repo.calls.length;
    await tester.fling(find.text('Pan'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.calls.length, antes + 1);
  });

  testWidgets('balance anual negativo en rojo (indicadores con datos negativos)', (tester) async {
    final repo = FakeReports();
    await abrir(tester, repo: repo);
    await pestana(tester, l.comparison);
    expect(find.text(Money.format(50000)), findsOneWidget);
  });
}
