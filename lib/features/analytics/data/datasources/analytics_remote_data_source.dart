import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/category_expense_report_model.dart';
import '../models/daily_evolution_model.dart';
import '../models/monthly_comparison_model.dart';
import '../models/product_price_model.dart';


final analyticsRemoteDataSourceProvider = Provider<AnalyticsRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AnalyticsRemoteDataSource(dioClient);
});

class AnalyticsRemoteDataSource {
  final DioClient _dioClient;

  AnalyticsRemoteDataSource(this._dioClient);

  String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<CategoryExpenseReportModel> getCategoryExpenseReport({
    DateTime? desde,
    DateTime? hasta,
    int? idLugar,
    int? idCategoria,
  }) async {
    final queryParams = <String, dynamic>{};
    if (desde != null) queryParams['desde'] = _formatDate(desde);
    if (hasta != null) queryParams['hasta'] = _formatDate(hasta);
    if (idLugar != null && idLugar > 0) queryParams['id_lugar'] = idLugar;
    if (idCategoria != null && idCategoria > 0) queryParams['id_categoria'] = idCategoria;

    final response = await _dioClient.get(
      ApiEndpoints.reporteGastosPorCategoria,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return CategoryExpenseReportModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido en reporte de categorías');
  }

  Future<MonthlyComparisonReportModel> getMonthlyComparisonReport({
    int? anio,
  }) async {
    final queryParams = <String, dynamic>{};
    if (anio != null) queryParams['anio'] = anio;

    final response = await _dioClient.get(
      ApiEndpoints.reporteComparativaMensual,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return MonthlyComparisonReportModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido en comparativa mensual');
  }

  Future<DailyEvolutionReportModel> getDailyEvolutionReport({
    required int mes,
    required int anio,
  }) async {
    final response = await _dioClient.get(
      ApiEndpoints.reporteEvolucionDiaria,
      queryParameters: {'mes': mes, 'anio': anio},
    );

    if (response is Map<String, dynamic>) {
      return DailyEvolutionReportModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido en evolución diaria');
  }

  Future<List<ProductPriceItemModel>> getProductPrices({
    String? search,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await _dioClient.get(
      ApiEndpoints.reportePreciosProductos,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      final rawList = response['productos'] as List<dynamic>? ?? [];
      return rawList
          .map((e) => ProductPriceItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Formato de respuesta inválido en catálogo de precios');
  }

  Future<ProductPriceHistoryModel> getProductPriceHistory(String concepto) async {
    final response = await _dioClient.get(
      ApiEndpoints.reporteHistorialProducto,
      queryParameters: {'concepto': concepto},
    );

    if (response is Map<String, dynamic>) {
      return ProductPriceHistoryModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido en historial de precios');
  }

  Future<PriceComparisonResultModel> comparePrices({
    required String desde1,
    required String hasta1,
    required String desde2,
    required String hasta2,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.reporteComparativaPrecios,
      data: {
        'desde1': desde1,
        'hasta1': hasta1,
        'desde2': desde2,
        'hasta2': hasta2,
      },
    );

    if (response is Map<String, dynamic>) {
      return PriceComparisonResultModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido en comparativa de precios');
  }
}

