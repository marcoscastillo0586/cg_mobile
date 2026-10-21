import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/category_expense_report_entity.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/daily_evolution_entity.dart';
import 'package:gastos_mobile/features/analytics/domain/entities/monthly_comparison_entity.dart';
import 'package:gastos_mobile/features/analytics/presentation/providers/analytics_state.dart';

void main() {
  group('AnalyticsState & Entities Tests', () {
    test('CategoryExpenseReportEntity calcula y almacena correctamente', () {
      const item1 = CategoryExpenseItemEntity(
        idCategoria: 3,
        nombre: 'Comida',
        monto: 150000.0,
        porcentaje: 60.0,
        cantidadMovimientos: 15,
      );
      const item2 = CategoryExpenseItemEntity(
        idCategoria: 8,
        nombre: 'Carne',
        monto: 100000.0,
        porcentaje: 40.0,
        cantidadMovimientos: 5,
      );

      const report = CategoryExpenseReportEntity(
        desde: '2026-10-01',
        hasta: '2026-10-31',
        totalGastos: 250000.0,
        categorias: [item1, item2],
        subcategorias: [],
      );

      expect(report.totalGastos, 250000.0);
      expect(report.categorias.length, 2);
      expect(report.categorias.first.porcentaje, 60.0);
    });

    test('MonthlyComparisonReportEntity calcula superávits y totales anuales', () {
      const mesEne = MonthFinancialDataEntity(
        mes: 1,
        nombreMes: 'Enero',
        ingresos: 500000.0,
        egresos: 400000.0,
        balance: 100000.0,
        tasaAhorro: 20.0,
      );
      const mesFeb = MonthFinancialDataEntity(
        mes: 2,
        nombreMes: 'Febrero',
        ingresos: 400000.0,
        egresos: 450000.0,
        balance: -50000.0,
        tasaAhorro: -12.5,
      );

      expect(mesEne.esSuperavit, isTrue);
      expect(mesFeb.esSuperavit, isFalse);

      const totales = AnnualTotalsEntity(
        totalIngresos: 900000.0,
        totalEgresos: 850000.0,
        balanceNeto: 50000.0,
        tasaAhorroPorcentaje: 5.56,
        promedioMensualGasto: 425000.0,
        mesMayorGasto: MonthExtremeEntity(mes: 2, nombre: 'Febrero', monto: 450000.0),
        mesMenorGasto: MonthExtremeEntity(mes: 1, nombre: 'Enero', monto: 400000.0),
      );

      expect(totales.balanceNeto, 50000.0);
      expect(totales.mesMayorGasto.nombre, 'Febrero');
    });

    test('DailyEvolutionReportEntity detecta pico máximo y acumulados', () {
      const dias = [
        DailyEvolutionItemEntity(dia: 1, fecha: '2026-10-01', ingresos: 0, egresos: 12000.0),
        DailyEvolutionItemEntity(dia: 2, fecha: '2026-10-02', ingresos: 0, egresos: 45000.0),
        DailyEvolutionItemEntity(dia: 3, fecha: '2026-10-03', ingresos: 200000.0, egresos: 8000.0),
      ];

      const report = DailyEvolutionReportEntity(
        mes: 10,
        anio: 2026,
        diasEnMes: 31,
        dias: dias,
      );

      expect(report.totalEgresosMes, 65000.0);
      expect(report.totalIngresosMes, 200000.0);
      expect(report.maximoGastoDiario, 45000.0);
    });

    test('AnalyticsState inicializa con valores por defecto del mes en curso', () {
      final state = AnalyticsState.initial();
      final now = DateTime.now();

      expect(state.status, AnalyticsStatus.initial);
      expect(state.activeTab, 0);
      expect(state.selectedPeriodo, 'mes_actual');
      expect(state.selectedAnio, now.year);
      expect(state.selectedMesDiario, now.month);
    });
  });
}
