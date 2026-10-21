import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/category_admin_model.dart';

final categoriesAdminRemoteDataSourceProvider =
    Provider<CategoriesAdminRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return CategoriesAdminRemoteDataSource(dioClient);
});

class CategoriesAdminRemoteDataSource {
  final DioClient _dioClient;

  CategoriesAdminRemoteDataSource(this._dioClient);

  Future<List<CategoryAdminModel>> getCategories({bool todas = true}) async {
    final response = await _dioClient.get(
      ApiEndpoints.categorias,
      queryParameters: {'todas': todas ? '1' : '0'},
    );

    if (response is List) {
      return response
          .map((e) => CategoryAdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<CategoryAdminModel> createCategory({required String nombre}) async {
    final response = await _dioClient.post(
      ApiEndpoints.crearCategoria,
      data: {'nombre': nombre},
    );

    if (response is Map<String, dynamic>) {
      return CategoryAdminModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido al crear categoría');
  }

  Future<CategoryAdminModel> updateCategory({
    required int idCategoria,
    required String nombre,
    required bool activa,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.editarCategoria,
      data: {
        'id_categoria': idCategoria,
        'nombre': nombre,
        'activa': activa,
      },
    );

    if (response is Map<String, dynamic>) {
      return CategoryAdminModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido al actualizar categoría');
  }

  Future<bool> toggleCategoryStatus({
    required int idCategoria,
    required bool activa,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.cambiarEstadoCategoria,
      data: {
        'id_categoria': idCategoria,
        'activa': activa,
      },
    );

    return response != null;
  }

  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteCategory({
    required int idCategoria,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.eliminarCategoria,
      data: {'id_categoria': idCategoria},
    );

    if (response is Map<String, dynamic>) {
      final eliminadoFisico = response['eliminado_fisico'] as bool? ?? false;
      final desactivado = response['desactivado'] as bool? ?? false;
      final mensaje = response['mensaje'] as String? ??
          (eliminadoFisico
              ? 'Categoría eliminada permanentemente'
              : 'Categoría desactivada');
      return (
        eliminadoFisico: eliminadoFisico,
        desactivado: desactivado,
        mensaje: mensaje
      );
    }

    return (
      eliminadoFisico: true,
      desactivado: false,
      mensaje: 'Operación realizada con éxito'
    );
  }
}
