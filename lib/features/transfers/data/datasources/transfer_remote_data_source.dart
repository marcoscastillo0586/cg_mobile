import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../dashboard/data/models/account_model.dart';
import '../../../dashboard/domain/entities/account_entity.dart';

final transferRemoteDataSourceProvider = Provider<TransferRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return TransferRemoteDataSource(dioClient);
});

class TransferRemoteDataSource {
  final DioClient _dioClient;

  TransferRemoteDataSource(this._dioClient);

  Future<List<AccountEntity>> getLugares() async {
    final response = await _dioClient.get(ApiEndpoints.formularioEgreso);
    if (response is Map<String, dynamic>) {
      final rawLugares = response['lugares'] as List<dynamic>? ?? [];
      return rawLugares
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<bool> createTransfer({
    required int idOrigen,
    required int idDestino,
    required double monto,
    required String concepto,
    required String fecha,
  }) async {
    final payload = {
      'id_lugar_origen': idOrigen,
      'id_lugar_destino': idDestino,
      'monto': monto,
      'concepto': concepto,
      'fecha': fecha,
    };

    final response = await _dioClient.post(
      ApiEndpoints.crearTransferencia,
      data: payload,
    );

    return response != null;
  }
}
