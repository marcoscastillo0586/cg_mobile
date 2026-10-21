import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/dashboard_summary_model.dart';
import '../models/expense_limit_model.dart';

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DashboardRemoteDataSource(dioClient);
});

class DashboardRemoteDataSource {
  final DioClient _dioClient;

  DashboardRemoteDataSource(this._dioClient);

  Future<DashboardSummaryModel> getSaldos({String? hasta}) async {
    final queryParams = <String, dynamic>{};
    if (hasta != null && hasta.isNotEmpty) {
      queryParams['hasta'] = hasta;
    }

    final response = await _dioClient.get(
      ApiEndpoints.dashboardSaldos,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return DashboardSummaryModel.fromJson(response);
    }

    throw Exception('Formato de datos no reconocido al obtener saldos');
  }

  Future<List<ExpenseLimitModel>> getLimites() async {
    final response = await _dioClient.get(ApiEndpoints.dashboardLimites);

    if (response is List) {
      return response
          .map((e) => ExpenseLimitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
