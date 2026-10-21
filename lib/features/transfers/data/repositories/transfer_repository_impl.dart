import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../dashboard/domain/entities/account_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_data_source.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final remoteDataSource = ref.watch(transferRemoteDataSourceProvider);
  return TransferRepositoryImpl(remoteDataSource);
});

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource _remoteDataSource;

  TransferRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AccountEntity>> getLugares() async {
    try {
      return await _remoteDataSource.getLugares();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> createTransfer({
    required int idOrigen,
    required int idDestino,
    required double monto,
    required String concepto,
    required String fecha,
  }) async {
    // Las escrituras pasan por SQLite y la cola de sincronización (etapa 5). Hasta entonces
    // se informa, en lugar de simular un éxito.
    throw const ServerFailure('Función no disponible por ahora', null, 'NOT_AVAILABLE');
  }
}
