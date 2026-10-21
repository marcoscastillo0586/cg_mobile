import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../expenses/data/datasources/expenses_local_data_source.dart';
import '../../domain/entities/movement_detail_entity.dart';
import '../../domain/entities/movement_entity.dart';
import '../../domain/repositories/movement_repository.dart';
import '../datasources/movement_remote_data_source.dart';

final movementRepositoryProvider = Provider<MovementRepository>((ref) {
  final remoteDataSource = ref.watch(movementRemoteDataSourceProvider);
  final localDataSource = ref.watch(expensesLocalDataSourceProvider);
  return MovementRepositoryImpl(remoteDataSource, localDataSource);
});

class MovementRepositoryImpl implements MovementRepository {
  final MovementRemoteDataSource _remoteDataSource;
  final ExpensesLocalDataSource _localDataSource;

  MovementRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<({List<MovementEntity> movimientos, MovementsSummaryEntity resumen})> getMovements({
    String? desde,
    String? hasta,
    int? idLugar,
    int? idCategoria,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _remoteDataSource.getMovements(
        desde: desde,
        hasta: hasta,
        idLugar: idLugar,
        idCategoria: idCategoria,
        limit: limit,
        offset: offset,
      );
      return (movimientos: res.movimientos, resumen: res.resumen);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.statusCode);
    } on NetworkException catch (_) {
      return await _localDataSource.getMovementsLocally(
        desde: desde,
        hasta: hasta,
        idLugar: idLugar,
        idCategoria: idCategoria,
        limit: limit,
      );
    } catch (_) {
      return await _localDataSource.getMovementsLocally(
        desde: desde,
        hasta: hasta,
        idLugar: idLugar,
        idCategoria: idCategoria,
        limit: limit,
      );
    }
  }

  @override
  Future<({List<MovementEntity> movimientos, Map<int, MovementDetailEntity> detallesSearchResult})> searchMovements({
    required String query,
    String? desde,
    String? hasta,
    int? idLugar,
  }) async {
    try {
      final res = await _remoteDataSource.searchMovements(
        query: query,
        desde: desde,
        hasta: hasta,
        idLugar: idLugar,
      );
      return (movimientos: res.movimientos, detallesSearchResult: res.detallesSearchResult);
    } catch (_) {
      final localRes = await _localDataSource.getMovementsLocally(
        desde: desde,
        hasta: hasta,
        idLugar: idLugar,
      );
      return (movimientos: localRes.movimientos, detallesSearchResult: <int, MovementDetailEntity>{});
    }
  }

  @override
  Future<MovementDetailEntity> getMovementDetail(int id) async {
    try {
      return await _remoteDataSource.getMovementDetail(id);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.statusCode);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.statusCode);
    } catch (e) {
      throw ServerFailure('Error al obtener detalle del movimiento: $e');
    }
  }

  @override
  Future<bool> updateMovement(Map<String, dynamic> data) async {
    try {
      return await _remoteDataSource.updateMovement(data);
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> deleteMovement(int id) async {
    try {
      return await _remoteDataSource.deleteMovement(id);
    } catch (_) {
      return true;
    }
  }
}
