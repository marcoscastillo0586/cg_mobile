import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense_limit_admin_entity.dart';
import '../../domain/repositories/limits_admin_repository.dart';
import '../datasources/limits_admin_remote_data_source.dart';
import '../datasources/limits_local_data_source.dart';

final limitsAdminRepositoryProvider = Provider<LimitsAdminRepository>((ref) {
  final remoteDataSource = ref.watch(limitsAdminRemoteDataSourceProvider);
  final localDataSource = ref.watch(limitsLocalDataSourceProvider);
  return LimitsAdminRepositoryImpl(remoteDataSource, localDataSource);
});

class LimitsAdminRepositoryImpl implements LimitsAdminRepository {
  final LimitsAdminRemoteDataSource _remoteDataSource;
  final LimitsLocalDataSource _localDataSource;

  LimitsAdminRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<List<ExpenseLimitAdminEntity>> getLimits() async {
    try {
      final remoteList = await _remoteDataSource.getLimits();
      await _localDataSource.cacheLimits(remoteList);
    } catch (_) {}
    return await _localDataSource.getLimits();
  }

  @override
  Future<ExpenseLimitAdminEntity> createLimit({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  }) async {
    try {
      final remoteLim = await _remoteDataSource.createLimit(
        desde: desde,
        hasta: hasta,
        montoLimite: montoLimite,
        categoriasIds: categoriasIds,
        lugaresIds: lugaresIds,
      );
      await _localDataSource.cacheLimits([remoteLim]);
      return remoteLim;
    } catch (_) {
      return await _localDataSource.createLimitLocally(
        desde: desde,
        hasta: hasta,
        montoLimite: montoLimite,
        categoriasIds: categoriasIds,
        lugaresIds: lugaresIds,
      );
    }
  }

  @override
  Future<bool> updateLimit({
    required int idLimiteGasto,
    required double montoLimite,
    DateTime? desde,
    DateTime? hasta,
    List<int>? categoriasIds,
    List<int>? lugaresIds,
  }) async {
    try {
      final ok = await _remoteDataSource.updateLimit(
        idLimiteGasto: idLimiteGasto,
        montoLimite: montoLimite,
        desde: desde,
        hasta: hasta,
        categoriasIds: categoriasIds,
        lugaresIds: lugaresIds,
      );
      if (ok) {
        await _localDataSource.updateLimitLocally(
          idLimiteGasto: idLimiteGasto,
          montoLimite: montoLimite,
        );
      }
      return ok;
    } catch (_) {
      return await _localDataSource.updateLimitLocally(
        idLimiteGasto: idLimiteGasto,
        montoLimite: montoLimite,
      );
    }
  }

  @override
  Future<bool> renewLimit({required int idLimiteGasto}) async {
    try {
      return await _remoteDataSource.renewLimit(idLimiteGasto: idLimiteGasto);
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> deleteLimit({required int idLimiteGasto}) async {
    try {
      final ok = await _remoteDataSource.deleteLimit(idLimiteGasto: idLimiteGasto);
      await _localDataSource.deleteLimitLocally(idLimiteGasto);
      return ok;
    } catch (_) {
      return await _localDataSource.deleteLimitLocally(idLimiteGasto);
    }
  }
}
