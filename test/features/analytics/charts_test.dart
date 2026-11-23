// Gráficos de informes: qué queda resaltado al tocar, el centro de la dona y el caso sin gastos.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/category_expense_report_entity.dart';
import 'package:gastos_mobile/features/analytics/presentation/widgets/category_pie_chart.dart';
import 'package:gastos_mobile/features/analytics/presentation/widgets/chart_touch.dart';
import 'package:gastos_mobile/features/analytics/presentation/widgets/monthly_bar_chart.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';
import 'fake_reports.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  test('toque: con el dedo apoyado sobre un elemento lo resalta; al soltar o fuera, nada', () {
    expect(resaltadoTrasToque(interesado: true, tocado: 2), 2);
    expect(resaltadoTrasToque(interesado: false, tocado: 2), -1);
    expect(resaltadoTrasToque(interesado: true), -1);
  });

  Future<void> pintar(WidgetTester tester, Widget chart) async {
    FlutterSecureStorage.setMockInitialValues({});
    await pumpScreen(tester, Scaffold(body: SingleChildScrollView(child: chart)));
  }

  testWidgets('dona: el centro muestra el total; tocar una categoría la muestra; otra vez vuelve al total', (tester) async {
    await pintar(tester, const CategoryPieChart(report: categorias));
    expect(find.text(l.totalExpenses), findsOneWidget);
    expect(find.text(Money.format(30000)), findsOneWidget);
    await tester.tap(find.text('Transporte'));
    await tester.pumpAndSettle();
    expect(find.text('Transporte'), findsNWidgets(2)); // en el centro y en la lista
    expect(find.text(l.tostringasfixedTotal('33.3')), findsOneWidget);
    await tester.tap(find.text('Transporte').last);
    await tester.pumpAndSettle();
    expect(find.text(l.totalExpenses), findsOneWidget);
  });

  testWidgets('dona sin gastos en el período', (tester) async {
    await pintar(tester, const CategoryPieChart(report: CategoryExpenseReportEntity(desde: 'a', hasta: 'b', totalCents: 0, categorias: [], subcategorias: [])));
    expect(find.text(l.noExpensesPeriod), findsOneWidget);
  });

  testWidgets('barras por mes: se dibujan con ingresos y egresos', (tester) async {
    await pintar(tester, MonthlyBarChart(report: comparativa(2026)));
    expect(find.byType(MonthlyBarChart), findsOneWidget);
  });
}
