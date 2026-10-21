import '../entities/category_admin_entity.dart';

abstract class CategoriesAdminRepository {
  /// Obtiene todas las categorías (activas e inactivas)
  Future<List<CategoryAdminEntity>> getCategories({bool todas = true});

  /// Crea una nueva categoría
  Future<CategoryAdminEntity> createCategory({required String nombre});

  /// Actualiza una categoría existente
  Future<CategoryAdminEntity> updateCategory({
    required int idCategoria,
    required String nombre,
    required bool activa,
  });

  /// Activa o desactiva una categoría
  Future<bool> toggleCategoryStatus({
    required int idCategoria,
    required bool activa,
  });

  /// Elimina una categoría físicamente o la desactiva si tiene movimientos
  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteCategory({
    required int idCategoria,
  });
}
