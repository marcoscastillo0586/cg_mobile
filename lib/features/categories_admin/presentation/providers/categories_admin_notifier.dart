import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_categories_repository.dart';
import 'categories_admin_state.dart';

final categoriesAdminNotifierProvider =
    StateNotifierProvider.autoDispose<CategoriesAdminNotifier, CategoriesAdminState>((ref) {
  return CategoriesAdminNotifier(ref.watch(localCategoriesRepositoryProvider));
});

/// Categorías desde la base local; alta, renombrar, activar/desactivar y baja por la outbox.
class CategoriesAdminNotifier extends StateNotifier<CategoriesAdminState> {
  final Future<LocalCategoriesRepository> _repository;

  CategoriesAdminNotifier(this._repository) : super(CategoriesAdminState.initial());

  Future<void> cargarCategorias() async {
    state = state.copyWith(status: CategoriesAdminStatus.loading, clearError: true);
    try {
      final categorias = await (await _repository).list();
      if (!mounted) return;
      state = state.copyWith(status: CategoriesAdminStatus.loaded, categorias: categorias);
    } catch (e) {
      debugPrint('[CATEGORIAS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: CategoriesAdminStatus.error, error: e);
    }
  }

  /// Ejecuta una acción local y recarga. Devuelve el error (para mostrarlo) o null.
  Future<Object?> run(Future<Object?> Function(LocalCategoriesRepository repo) action) async {
    try {
      await action(await _repository);
      await cargarCategorias();
      return null;
    } catch (e) {
      debugPrint('[CATEGORIAS] No se guardó: $e');
      return e;
    }
  }

  void setBusqueda(String value) => state = state.copyWith(busqueda: value);

  void setFiltroEstado(String value) => state = state.copyWith(filtroEstado: value);
}
