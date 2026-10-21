import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/balances.dart';
import '../models/balances_dto.dart';

final balancesRepositoryProvider = Provider<BalancesRepository>((ref) {
  return BalancesRepository(ref.watch(dioClientProvider));
});

/// Saldos por cuenta y consolidado (GET /accounts/balances). Solo lectura.
class BalancesRepository {
  final DioClient _client;
  BalancesRepository(this._client);

  /// [until] en formato `yyyy-MM-dd`; el servidor incluye el día completo.
  Future<Balances> getBalances({String? until}) async {
    final data = await _client.get(
      '/accounts/balances',
      queryParameters: {if (until != null && until.isNotEmpty) 'until': until},
    );
    return BalancesDto.fromJson(data);
  }
}
