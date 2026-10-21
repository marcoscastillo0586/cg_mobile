import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../dashboard/domain/entities/account_entity.dart';
import '../../domain/repositories/income_repository.dart';
import '../datasources/income_remote_data_source.dart';

final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  final remoteDataSource = ref.watch(incomeRemoteDataSourceProvider);
  return IncomeRepositoryImpl(remoteDataSource);
});

class IncomeRepositoryImpl implements IncomeRepository {
  final IncomeRemoteDataSource _remoteDataSource;

  IncomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AccountEntity>> getLugares() async {
    try {
      return await _remoteDataSource.getLugares();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> createIncome({
    required int idLugar,
    required double monto,
    required String concepto,
    required String fecha,
  }) async {
    // Las escrituras pasan por SQLite y la cola de sincronización (etapa 5). Hasta entonces
    // se informa, en lugar de simular un éxito.
    throw const ServerFailure('Función no disponible por ahora', null, 'NOT_AVAILABLE');
  }
}
