import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/expense_limit_admin_model.dart';

final limitsAdminRemoteDataSourceProvider =
    Provider<LimitsAdminRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return LimitsAdminRemoteDataSource(dioClient);
});

class LimitsAdminRemoteDataSource {
  final DioClient _dioClient;

  LimitsAdminRemoteDataSource(this._dioClient);

  String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<List<ExpenseLimitAdminModel>> getLimits() async {
    final response = await _dioClient.get(ApiEndpoints.limites);

    if (response is List) {
      return response
          .map((e) => ExpenseLimitAdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<ExpenseLimitAdminModel> createLimit({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.crearLimite,
      data: {
        'desde': _formatDate(desde),
        'hasta': _formatDate(hasta),
        'monto_limite': montoLimite,
        'categoria': categoriasIds.join(','),
        'lugar': lugaresIds.join(','),
      },
    );

    if (response is Map<String, dynamic>) {
      return ExpenseLimitAdminModel.fromJson(response);
    }

    throw Exception('Respuesta inesperada al crear el presupuesto');
  }

  Future<bool> updateLimit({
    required int idLimiteGasto,
    required double montoLimite,
    DateTime? desde,
    DateTime? hasta,
    List<int>? categoriasIds,
    List<int>? lugaresIds,
  }) async {
    final data = <String, dynamic>{
      'id_limite_gasto': idLimiteGasto,
      'monto_limite': montoLimite,
    };

    if (desde != null) {
      data['desde'] = _formatDate(desde);
    }
    if (hasta != null) {
      data['hasta'] = _formatDate(hasta);
    }
    if (categoriasIds != null && categoriasIds.isNotEmpty) {
      data['categoria'] = categoriasIds.join(',');
    }
    if (lugaresIds != null && lugaresIds.isNotEmpty) {
      data['lugar'] = lugaresIds.join(',');
    }

    final response = await _dioClient.post(
      ApiEndpoints.editarLimite,
      data: data,
    );

    return response != null;
  }

  Future<bool> renewLimit({required int idLimiteGasto}) async {
    final response = await _dioClient.post(
      ApiEndpoints.renovarLimite,
      data: {'id_limite_gasto': idLimiteGasto},
    );

    return response != null;
  }

  Future<bool> deleteLimit({required int idLimiteGasto}) async {
    final response = await _dioClient.post(
      ApiEndpoints.eliminarLimite,
      data: {'id_limite_gasto': idLimiteGasto},
    );

    return response != null;
  }
}
