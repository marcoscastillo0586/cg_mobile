import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
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
    try {
      return await _remoteDataSource.createIncome(
        idLugar: idLugar,
        monto: monto,
        concepto: concepto,
        fecha: fecha,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.statusCode);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.statusCode);
    } catch (e) {
      throw ServerFailure('Error al registrar ingreso: $e');
    }
  }
}
