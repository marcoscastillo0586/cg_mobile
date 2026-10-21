import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../dashboard/data/models/account_model.dart';
import '../../../dashboard/domain/entities/account_entity.dart';

final incomeRemoteDataSourceProvider = Provider<IncomeRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return IncomeRemoteDataSource(dioClient);
});

class IncomeRemoteDataSource {
  final DioClient _dioClient;

  IncomeRemoteDataSource(this._dioClient);

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

}
