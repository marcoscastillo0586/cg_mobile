import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/account_admin_model.dart';

final accountsAdminRemoteDataSourceProvider =
    Provider<AccountsAdminRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AccountsAdminRemoteDataSource(dioClient);
});

class AccountsAdminRemoteDataSource {
  final DioClient _dioClient;

  AccountsAdminRemoteDataSource(this._dioClient);

  Future<List<AccountAdminModel>> getAccounts({bool todos = true}) async {
    final response = await _dioClient.get(
      ApiEndpoints.lugares,
      queryParameters: {'todos': todos ? '1' : '0'},
    );

    if (response is List) {
      return response
          .map((e) => AccountAdminModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<AccountAdminModel> createAccount({
    required String nombre,
    required int tipoMoneda,
    String? img,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.crearLugar,
      data: {
        'nombre': nombre,
        'tipo_moneda': tipoMoneda,
        if (img != null && img.isNotEmpty) 'img': img,
      },
    );

    if (response is Map<String, dynamic>) {
      return AccountAdminModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido al crear cuenta');
  }

  Future<AccountAdminModel> updateAccount({
    required int idLugar,
    required String nombre,
    required int tipoMoneda,
    required bool activo,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.editarLugar,
      data: {
        'id_lugar': idLugar,
        'nombre': nombre,
        'tipo_moneda': tipoMoneda,
        'activo': activo,
      },
    );

    if (response is Map<String, dynamic>) {
      return AccountAdminModel.fromJson(response);
    }

    throw Exception('Formato de respuesta inválido al actualizar cuenta');
  }

  Future<bool> toggleAccountStatus({
    required int idLugar,
    required bool activo,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.cambiarEstadoLugar,
      data: {
        'id_lugar': idLugar,
        'activo': activo,
      },
    );

    return response != null;
  }

  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteAccount({
    required int idLugar,
  }) async {
    final response = await _dioClient.post(
      ApiEndpoints.eliminarLugar,
      data: {'id_lugar': idLugar},
    );

    if (response is Map<String, dynamic>) {
      final eliminadoFisico = response['eliminado_fisico'] as bool? ?? false;
      final desactivado = response['desactivado'] as bool? ?? false;
      final mensaje = response['mensaje'] as String? ??
          (eliminadoFisico
              ? 'Cuenta eliminada permanentemente'
              : 'Cuenta desactivada');
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
