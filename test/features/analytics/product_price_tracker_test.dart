// Pestaña "Precios": lista y búsqueda, historial de un producto y monitor de inflación, con reportes SIMULADOS.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/analytics/data/reports_repository.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/product_price_entity.dart';
import 'package:gastos_mobile/features/analytics/presentation/widgets/product_price_tracker_view.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';
import 'fake_reports.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  Future<FakeReports> abrir(WidgetTester tester, {FakeReports? repo}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final r = repo ?? FakeReports();
    await pumpScreen(tester, const Scaffold(body: ProductPriceTrackerView()), overrides: [reportsRepositoryProvider.overrideWithValue(r)]);
    return r;
  }

  test('variación con signo, día/mes del eje y períodos del monitor (cruza el año)', () {
    expect(variacion(12.54), '+12.5%');
    expect(variacion(-3), '-3.0%');
    expect(variacion(0), '0.0%');
    expect(diaMes('2026-11-10 10:00:00'), '10/11');
    expect(diaMes('ayer'), 'ayer');
    expect(periodosInflacion(DateTime(2026, 1, 15)), ((DateTime(2025, 12, 1), DateTime(2025, 12, 31)), (DateTime(2026, 1, 1), DateTime(2026, 1, 31))));
  });

  testWidgets('lista con precio, compras, lugar y variación; buscar filtra y la cruz limpia', (tester) async {
    final repo = await abrir(tester);
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text(Money.format(1500)), findsOneWidget);
    expect(find.text('${l.purchasesCount(3)} • Súper'), findsOneWidget);
    expect(find.text('+50.0%'), findsOneWidget);
    expect(find.text('-10.0%'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('buscar-precios')), 'lec');
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'productos lec');
    expect(find.text('Pan'), findsNothing);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'productos ');
    expect(find.text('Pan'), findsOneWidget);
  });

  testWidgets('sin productos: explica cuándo aparecen', (tester) async {
    await abrir(tester, repo: FakeReports()..productos = const []);
    expect(find.text(l.noRecordedItemsFound), findsOneWidget);
  });

  testWidgets('historial: con PLU pide el producto exacto; indicadores, gráfico y compras', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'historial null 779');
    expect(find.text(l.currentPrice), findsOneWidget);
    expect(find.text(l.unitPriceTrend), findsOneWidget); // dos compras o más: gráfico
    expect(find.text('2026-11-10 • Súper'), findsOneWidget);
    expect(find.text('Total ${Money.format(3000)}'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(l.currentPrice), findsNothing);
  });

  testWidgets('historial sin PLU va por concepto; un error muestra el motivo con su código', (tester) async {
    final repo = await abrir(tester);
    repo.error = const ServerException('caído', 500, 'INTERNAL_ERROR');
    await tester.tap(find.text('Leche'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'historial Leche null');
    expect(find.textContaining('(INTERNAL_ERROR)'), findsOneWidget);
  });

  testWidgets('monitor de inflación: promedio, productos que subieron y detalle', (tester) async {
    final repo = await abrir(tester);
    final gate = repo.gate = Completer();
    await tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.calls.last, startsWith('comparar '));
    expect(find.text('+12.5%'), findsOneWidget);
    expect(find.text(l.productoscomunesItemsComparedProductosaumentaronWent(2, 1)), findsOneWidget);
    expect(find.text(l.beforePrecio1centsNowPrecio2cents(Money.format(1000), Money.format(1500))), findsOneWidget);
  });

  testWidgets('monitor sin productos en común, o con error', (tester) async {
    final repo = await abrir(tester);
    repo.comparada = const PriceComparisonResultEntity(productosComunes: 0, inflacionPromedio: 0, comparativa: []);
    await tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await tester.pumpAndSettle();
    expect(find.text(l.noIdenticalItemsWerePurchased), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    repo.error = const ServerException('caído', 500, 'INTERNAL_ERROR');
    await tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('(INTERNAL_ERROR)'), findsOneWidget);
  });
}
