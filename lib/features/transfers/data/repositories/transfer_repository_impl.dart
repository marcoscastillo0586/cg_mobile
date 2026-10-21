import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
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
    try {
      return await _remoteDataSource.createTransfer(
        idOrigen: idOrigen,
        idDestino: idDestino,
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
      throw ServerFailure('Error al realizar transferencia: $e');
    }
  }
}
