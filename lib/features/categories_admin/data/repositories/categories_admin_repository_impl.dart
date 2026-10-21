import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category_admin_entity.dart';
import '../../domain/repositories/categories_admin_repository.dart';
import '../datasources/categories_admin_remote_data_source.dart';
import '../datasources/categories_local_data_source.dart';

final categoriesAdminRepositoryProvider = Provider<CategoriesAdminRepository>((ref) {
  final remoteDataSource = ref.watch(categoriesAdminRemoteDataSourceProvider);
  final localDataSource = ref.watch(categoriesLocalDataSourceProvider);
  return CategoriesAdminRepositoryImpl(remoteDataSource, localDataSource);
});

class CategoriesAdminRepositoryImpl implements CategoriesAdminRepository {
  final CategoriesAdminRemoteDataSource _remoteDataSource;
  final CategoriesLocalDataSource _localDataSource;

  CategoriesAdminRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<List<CategoryAdminEntity>> getCategories({bool todas = true}) async {
    try {
      final remoteList = await _remoteDataSource.getCategories(todas: todas);
      await _localDataSource.cacheCategories(remoteList);
    } catch (_) {}
    return await _localDataSource.getCategories(todas: todas);
  }

  @override
  Future<CategoryAdminEntity> createCategory({required String nombre}) async {
    try {
      final remoteCat = await _remoteDataSource.createCategory(nombre: nombre);
      await _localDataSource.cacheCategories([remoteCat]);
      return remoteCat;
    } catch (_) {
      return await _localDataSource.createCategoryLocally(nombre);
    }
  }

  @override
  Future<CategoryAdminEntity> updateCategory({
    required int idCategoria,
    required String nombre,
    required bool activa,
  }) async {
    try {
      final remoteCat = await _remoteDataSource.updateCategory(
        idCategoria: idCategoria,
        nombre: nombre,
        activa: activa,
      );
      await _localDataSource.cacheCategories([remoteCat]);
      return remoteCat;
    } catch (_) {
      return await _localDataSource.updateCategoryLocally(
        idCategoria: idCategoria,
        nombre: nombre,
        activa: activa,
      );
    }
  }

  @override
  Future<bool> toggleCategoryStatus({
    required int idCategoria,
    required bool activa,
  }) async {
    try {
      final ok = await _remoteDataSource.toggleCategoryStatus(
        idCategoria: idCategoria,
        activa: activa,
      );
      if (ok) {
        await _localDataSource.updateCategoryLocally(
          idCategoria: idCategoria,
          nombre: '',
          activa: activa,
        );
      }
      return ok;
    } catch (_) {
      await _localDataSource.updateCategoryLocally(
        idCategoria: idCategoria,
        nombre: '',
        activa: activa,
      );
      return true;
    }
  }

  @override
  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteCategory({
    required int idCategoria,
  }) async {
    try {
      final res = await _remoteDataSource.deleteCategory(idCategoria: idCategoria);
      await _localDataSource.deleteCategoryLocally(idCategoria);
      return res;
    } catch (_) {
      await _localDataSource.deleteCategoryLocally(idCategoria);
      return (eliminadoFisico: false, desactivado: true, mensaje: 'Categoría deshabilitada localmente (modo offline)');
    }
  }
}
