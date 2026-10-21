import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import 'package:gastos_mobile/features/dashboard/data/models/account_model.dart';
import '../../domain/entities/expense_form_data_entity.dart';
import '../models/category_model.dart';

final expenseRemoteDataSourceProvider = Provider<ExpenseRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ExpenseRemoteDataSource(dioClient);
});

class ExpenseRemoteDataSource {
  final DioClient _dioClient;

  ExpenseRemoteDataSource(this._dioClient);

  Future<ExpenseFormDataEntity> getFormData() async {
    final response = await _dioClient.get(ApiEndpoints.formularioEgreso);

    if (response is Map<String, dynamic>) {
      final rawLugares = response['lugares'] as List<dynamic>? ?? [];
      final rawCategorias = response['categorias'] as List<dynamic>? ?? [];
      final rawConceptos = response['conceptos'] as List<dynamic>? ?? [];

      final lugares = rawLugares
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final categorias = rawCategorias
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final conceptos = rawConceptos.map((e) => e.toString()).toList();

      return ExpenseFormDataEntity(
        lugares: lugares,
        categorias: categorias,
        conceptos: conceptos,
      );
    }

    throw Exception('Formato de datos no válido para formulario de egreso');
  }


  Future<int?> suggestCategory(String concepto) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.sugerirCategoria,
        data: {'concepto': concepto},
      );
      if (response is Map<String, dynamic> && response.containsKey('id_categoria')) {
        return response['id_categoria'] as int?;
      }
    } catch (_) {}
    return null;
  }
}
