import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../models/movement_detail_model.dart';
import '../models/movement_model.dart';

final movementRemoteDataSourceProvider = Provider<MovementRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return MovementRemoteDataSource(dioClient);
});

class MovementRemoteDataSource {
  final DioClient _dioClient;

  MovementRemoteDataSource(this._dioClient);

  Future<({List<MovementModel> movimientos, MovementsSummaryModel resumen})> getMovements({
    String? desde,
    String? hasta,
    int? idLugar,
    int? idCategoria,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (desde != null && desde.isNotEmpty) queryParams['desde'] = desde;
    if (hasta != null && hasta.isNotEmpty) queryParams['hasta'] = hasta;
    if (idLugar != null && idLugar > 0) queryParams['id_lugar'] = idLugar;
    if (idCategoria != null && idCategoria > 0) queryParams['id_categoria'] = idCategoria;

    final response = await _dioClient.get(
      ApiEndpoints.movimientos,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      final rawMovs = response['movimientos'] as List<dynamic>? ?? [];
      final rawResumen = response['resumen'] as Map<String, dynamic>? ?? {};

      final movimientos = rawMovs
          .map((e) => MovementModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final resumen = MovementsSummaryModel.fromJson(rawResumen);

      return (movimientos: movimientos, resumen: resumen);
    }

    throw Exception('Error al obtener movimientos del servidor');
  }

  Future<({List<MovementModel> movimientos, Map<int, MovementDetailModel> detallesSearchResult})> searchMovements({
    required String query,
    String? desde,
    String? hasta,
    int? idLugar,
  }) async {
    final queryParams = <String, dynamic>{
      'q': query,
    };
    if (desde != null && desde.isNotEmpty) queryParams['desde'] = desde;
    if (hasta != null && hasta.isNotEmpty) queryParams['hasta'] = hasta;
    if (idLugar != null && idLugar > 0) queryParams['id_lugar'] = idLugar;

    final response = await _dioClient.get(
      ApiEndpoints.movimientosBuscar,
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      final rawMovs = response['movimientos'] as List<dynamic>? ?? [];
      final List<MovementModel> movimientos = [];
      final Map<int, MovementDetailModel> detallesSearchResult = {};

      for (final e in rawMovs) {
        if (e is Map<String, dynamic>) {
          final mov = MovementModel.fromJson(e);
          movimientos.add(mov);

          final rawDetalles = e['detalles'] as List<dynamic>? ?? [];
          if (rawDetalles.isNotEmpty) {
            final Map<String, dynamic> fakeDetailMap = {
              'id_movimiento_enc': mov.idMovimientoEnc,
              'tipo_movimiento': mov.tipoMovimiento,
              'concepto_general': mov.conceptoGeneral,
              'fecha': mov.fecha,
              'monto_total': mov.monto,
              'id_lugar_origen': mov.idLugar,
              'id_lugar_destino': 0,
              'detalles': rawDetalles,
            };
            final detailModel = MovementDetailModel.fromJson(fakeDetailMap);
            detallesSearchResult[mov.idMovimientoEnc] = detailModel;
          }
        }
      }

      return (movimientos: movimientos, detallesSearchResult: detallesSearchResult);
    }

    throw Exception('Error al buscar movimientos');
  }

  Future<MovementDetailModel> getMovementDetail(int id) async {
    final response = await _dioClient.get(
      ApiEndpoints.movimientoDetalle,
      queryParameters: {'id': id},
    );

    if (response is Map<String, dynamic>) {
      return MovementDetailModel.fromJson(response);
    }

    throw Exception('No se pudo cargar el detalle del movimiento');
  }

  Future<bool> updateMovement(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiEndpoints.editarMovimiento,
      data: data,
    );
    return response != null;
  }

  Future<bool> deleteMovement(int id) async {
    final response = await _dioClient.post(
      ApiEndpoints.eliminarMovimiento,
      data: {'id': id},
    );
    return response != null;
  }
}
