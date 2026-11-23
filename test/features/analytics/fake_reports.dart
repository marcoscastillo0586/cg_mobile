// Repositorio de reportes en memoria con datos de ejemplo para las pantallas de informes.
import 'dart:async';
import 'package:gastos_mobile/features/analytics/data/reports_repository.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/category_expense_report_entity.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/daily_evolution_entity.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/monthly_comparison_entity.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/product_price_entity.dart';

const categorias = CategoryExpenseReportEntity(
  desde: '2026-11-01',
  hasta: '2026-11-30',
  totalCents: 30000,
  categorias: [
    CategoryExpenseItemEntity(idCategoria: 1, nombre: 'Comida', montoCents: 20000, porcentaje: 66.7),
    CategoryExpenseItemEntity(idCategoria: 2, nombre: 'Transporte', montoCents: 10000, porcentaje: 33.3),
  ],
  subcategorias: [SubcategoryExpenseItemEntity(etiqueta: 'Pan', montoCents: 5000, porcentaje: 16.7)],
);

MonthlyComparisonReportEntity comparativa(int anio, {int balance = 50000}) => MonthlyComparisonReportEntity(
      anio: anio,
      aniosDisponibles: const [2025, 2026],
      meses: const [
        MonthFinancialDataEntity(mes: 1, ingresosCents: 100000, egresosCents: 40000, balanceCents: 60000, tasaAhorro: 60),
        MonthFinancialDataEntity(mes: 2, ingresosCents: 10000, egresosCents: 20000, balanceCents: -10000, tasaAhorro: -100),
      ],
      totalesAnuales: AnnualTotalsEntity(
        totalIngresosCents: 110000,
        totalEgresosCents: 60000,
        balanceNetoCents: balance,
        tasaAhorroPorcentaje: 45.5,
        promedioMensualGastoCents: 30000,
        mesMayorGasto: const MonthExtremeEntity(mes: 1, montoCents: 40000),
        mesMenorGasto: const MonthExtremeEntity(mes: 2, montoCents: 20000),
      ),
      topCategorias: const [],
    );

DailyEvolutionReportEntity diaria(int mes) => DailyEvolutionReportEntity(mes: mes, anio: 2026, dias: [
      for (var d = 1; d <= 30; d++)
        DailyEvolutionItemEntity(dia: d, fecha: '2026-$mes-$d', ingresosCents: d == 1 ? 50000 : 0, egresosCents: d == 10 ? 7000 : d * 10),
    ]);

const pan = ProductPriceItemEntity(
  concepto: 'Pan',
  plu: '779',
  totalCompras: 3,
  ultimoPrecioCents: 1500,
  primerPrecioCents: 1000,
  precioMinimoCents: 1000,
  precioMaximoCents: 1500,
  variacionPorcentaje: 50,
  ultimaFecha: '2026-11-10',
  primeraFecha: '2026-09-01',
  ultimoLugar: 'Súper',
);
const leche = ProductPriceItemEntity(
  concepto: 'Leche',
  plu: null,
  totalCompras: 2,
  ultimoPrecioCents: 900,
  primerPrecioCents: 1000,
  precioMinimoCents: 900,
  precioMaximoCents: 1000,
  variacionPorcentaje: -10,
  ultimaFecha: '2026-11-05',
  primeraFecha: '2026-10-01',
  ultimoLugar: 'Almacén',
);

const historialPan = ProductPriceHistoryEntity(
  concepto: 'Pan',
  cantidadCompras: 2,
  precioActualCents: 1500,
  precioInicialCents: 1000,
  precioMinimoCents: 1000,
  precioMaximoCents: 1500,
  aumentoPorcentaje: 50,
  historial: [
    ProductPurchaseHistoryItemEntity(
        idMovimientoEnc: 1, fechaHora: '2026-09-01 10:00:00', lugarNombre: 'Súper', categoriaNombre: 'Comida', concepto: 'Pan', precioUnitarioCents: 1000, montoTotalCents: 1000),
    ProductPurchaseHistoryItemEntity(
        idMovimientoEnc: 2, fechaHora: '2026-11-10 10:00:00', lugarNombre: 'Súper', categoriaNombre: null, concepto: 'Pan', precioUnitarioCents: 1500, montoTotalCents: 3000),
  ],
);

const comparacion = PriceComparisonResultEntity(productosComunes: 2, inflacionPromedio: 12.5, comparativa: [
  PriceComparisonItemEntity(plu: '779', producto: 'Pan', precio1Cents: 1000, precio2Cents: 1500, diferenciaCents: 500, porcentaje: 50, cantidadPeriodo2: 2),
  PriceComparisonItemEntity(plu: '780', producto: 'Leche', precio1Cents: 1000, precio2Cents: 900, diferenciaCents: -100, porcentaje: -10, cantidadPeriodo2: 1),
]);

class FakeReports implements ReportsRepository {
  final calls = <String>[];
  Object? error;
  Completer<void>? gate;
  List<ProductPriceItemEntity> productos = const [pan, leche];
  PriceComparisonResultEntity comparada = comparacion;

  Future<T> _call<T>(String call, T Function() result) async {
    calls.add(call);
    await gate?.future;
    if (error != null) throw error!;
    return result();
  }

  @override
  Future<CategoryExpenseReportEntity> getCategoryReport({String? from, String? to, List<int> accountIds = const []}) =>
      _call('categorias $from $to', () => categorias);

  @override
  Future<MonthlyComparisonReportEntity> getIncomeExpense({int? year}) => _call('anual $year', () => comparativa(year!));

  @override
  Future<DailyEvolutionReportEntity> getDaily({required int year, required int month}) => _call('diaria $year-$month', () => diaria(month));

  @override
  Future<List<ProductPriceItemEntity>> getProducts({String? search, int limit = 50}) =>
      _call('productos $search', () => productos.where((p) => p.concepto.toLowerCase().contains((search ?? '').toLowerCase())).toList());

  @override
  Future<ProductPriceHistoryEntity> getProductHistory({String? concept, String? plu}) => _call('historial $concept $plu', () => historialPan);

  @override
  Future<PriceComparisonResultEntity> compareProducts({required String from1, required String to1, required String from2, required String to2}) =>
      _call('comparar $from1 $to1 $from2 $to2', () => comparada);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
