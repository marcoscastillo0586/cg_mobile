import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account_admin_entity.dart';
import '../../domain/repositories/accounts_admin_repository.dart';
import '../datasources/accounts_admin_remote_data_source.dart';
import '../datasources/accounts_local_data_source.dart';

final accountsAdminRepositoryProvider = Provider<AccountsAdminRepository>((ref) {
  final remoteDataSource = ref.watch(accountsAdminRemoteDataSourceProvider);
  final localDataSource = ref.watch(accountsLocalDataSourceProvider);
  return AccountsAdminRepositoryImpl(remoteDataSource, localDataSource);
});

class AccountsAdminRepositoryImpl implements AccountsAdminRepository {
  final AccountsAdminRemoteDataSource _remoteDataSource;
  final AccountsLocalDataSource _localDataSource;

  AccountsAdminRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<List<AccountAdminEntity>> getAccounts({bool todos = true}) async {
    try {
      final remoteList = await _remoteDataSource.getAccounts(todos: todos);
      await _localDataSource.cacheAccounts(remoteList);
    } catch (_) {}
    return await _localDataSource.getAccounts(todos: todos);
  }

  @override
  Future<AccountAdminEntity> createAccount({
    required String nombre,
    required int tipoMoneda,
    String? img,
  }) async {
    try {
      final remoteAcc = await _remoteDataSource.createAccount(
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        img: img,
      );
      await _localDataSource.cacheAccounts([remoteAcc]);
      return remoteAcc;
    } catch (_) {
      return await _localDataSource.createAccountLocally(
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        img: img,
      );
    }
  }

  @override
  Future<AccountAdminEntity> updateAccount({
    required int idLugar,
    required String nombre,
    required int tipoMoneda,
    required bool activo,
  }) async {
    try {
      final remoteAcc = await _remoteDataSource.updateAccount(
        idLugar: idLugar,
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        activo: activo,
      );
      await _localDataSource.cacheAccounts([remoteAcc]);
      return remoteAcc;
    } catch (_) {
      return await _localDataSource.updateAccountLocally(
        idLugar: idLugar,
        nombre: nombre,
        tipoMoneda: tipoMoneda,
        activo: activo,
      );
    }
  }

  @override
  Future<bool> toggleAccountStatus({
    required int idLugar,
    required bool activo,
  }) async {
    try {
      final ok = await _remoteDataSource.toggleAccountStatus(
        idLugar: idLugar,
        activo: activo,
      );
      if (ok) {
        await _localDataSource.updateAccountLocally(
          idLugar: idLugar,
          nombre: '',
          tipoMoneda: 1,
          activo: activo,
        );
      }
      return ok;
    } catch (_) {
      await _localDataSource.updateAccountLocally(
        idLugar: idLugar,
        nombre: '',
        tipoMoneda: 1,
        activo: activo,
      );
      return true;
    }
  }

  @override
  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteAccount({
    required int idLugar,
  }) async {
    try {
      final res = await _remoteDataSource.deleteAccount(idLugar: idLugar);
      await _localDataSource.deleteAccountLocally(idLugar);
      return res;
    } catch (_) {
      await _localDataSource.deleteAccountLocally(idLugar);
      return (eliminadoFisico: false, desactivado: true, mensaje: 'Cuenta deshabilitada localmente (modo offline)');
    }
  }
}
