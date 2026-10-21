import '../entities/category_expense_report_entity.dart';
import '../entities/daily_evolution_entity.dart';
import '../entities/monthly_comparison_entity.dart';
import '../entities/product_price_entity.dart';

abstract class AnalyticsRepository {
  /// Obtiene la distribución de gastos por categoría y conceptos en un rango de fechas
  Future<CategoryExpenseReportEntity> getCategoryExpenseReport({
    DateTime? desde,
    DateTime? hasta,
    int? idLugar,
    int? idCategoria,
  });

  /// Obtiene la comparativa mensual (Ingresos vs Egresos vs Ahorro) de un año
  Future<MonthlyComparisonReportEntity> getMonthlyComparisonReport({
    int? anio,
  });

  /// Obtiene la evolución diaria de gastos e ingresos dentro de un mes
  Future<DailyEvolutionReportEntity> getDailyEvolutionReport({
    required int mes,
    required int anio,
  });

  /// Obtiene el catálogo consolidado de precios de productos
  Future<List<ProductPriceItemEntity>> getProductPrices({
    String? search,
    int limit = 50,
  });

  /// Obtiene el historial temporal cronológico de precios de un producto
  Future<ProductPriceHistoryEntity> getProductPriceHistory(String concepto);

  /// Compara precios e inflación de artículos comunes entre 2 períodos
  Future<PriceComparisonResultEntity> comparePrices({
    required String desde1,
    required String hasta1,
    required String desde2,
    required String hasta2,
  });
}

