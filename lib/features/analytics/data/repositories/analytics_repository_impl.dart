import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_expense_report_entity.dart';
import '../../domain/entities/daily_evolution_entity.dart';
import '../../domain/entities/monthly_comparison_entity.dart';
import '../../domain/entities/product_price_entity.dart';
import '../../domain/repositories/analytics_repository.dart';

import '../datasources/analytics_remote_data_source.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final remoteDataSource = ref.watch(analyticsRemoteDataSourceProvider);
  return AnalyticsRepositoryImpl(remoteDataSource);
});

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource _remoteDataSource;

  AnalyticsRepositoryImpl(this._remoteDataSource);

  @override
  Future<CategoryExpenseReportEntity> getCategoryExpenseReport({
    DateTime? desde,
    DateTime? hasta,
    int? idLugar,
    int? idCategoria,
  }) async {
    return await _remoteDataSource.getCategoryExpenseReport(
      desde: desde,
      hasta: hasta,
      idLugar: idLugar,
      idCategoria: idCategoria,
    );
  }

  @override
  Future<MonthlyComparisonReportEntity> getMonthlyComparisonReport({
    int? anio,
  }) async {
    return await _remoteDataSource.getMonthlyComparisonReport(anio: anio);
  }

  @override
  Future<DailyEvolutionReportEntity> getDailyEvolutionReport({
    required int mes,
    required int anio,
  }) async {
    return await _remoteDataSource.getDailyEvolutionReport(
      mes: mes,
      anio: anio,
    );
  }

  @override
  Future<List<ProductPriceItemEntity>> getProductPrices({
    String? search,
    int limit = 50,
  }) async {
    return await _remoteDataSource.getProductPrices(
      search: search,
      limit: limit,
    );
  }

  @override
  Future<ProductPriceHistoryEntity> getProductPriceHistory(String concepto) async {
    return await _remoteDataSource.getProductPriceHistory(concepto);
  }

  @override
  Future<PriceComparisonResultEntity> comparePrices({
    required String desde1,
    required String hasta1,
    required String desde2,
    required String hasta2,
  }) async {
    return await _remoteDataSource.comparePrices(
      desde1: desde1,
      hasta1: hasta1,
      desde2: desde2,
      hasta2: hasta2,
    );
  }
}

