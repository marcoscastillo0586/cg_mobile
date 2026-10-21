import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/categories_repository.dart';
import 'categories_admin_state.dart';

final categoriesAdminNotifierProvider =
    StateNotifierProvider.autoDispose<CategoriesAdminNotifier, CategoriesAdminState>((ref) {
  return CategoriesAdminNotifier(ref.watch(categoriesRepositoryProvider));
});

/// Lista de categorías. Solo lectura en esta etapa (las escrituras, en la etapa 8).
class CategoriesAdminNotifier extends StateNotifier<CategoriesAdminState> {
  final CategoriesRepository _repository;

  CategoriesAdminNotifier(this._repository) : super(CategoriesAdminState.initial());

  Future<void> cargarCategorias() async {
    state = state.copyWith(status: CategoriesAdminStatus.loading, clearError: true);
    try {
      final categorias = await _repository.getCategories();
      if (!mounted) return;
      state = state.copyWith(status: CategoriesAdminStatus.loaded, categorias: categorias);
    } catch (e) {
      debugPrint('[CATEGORIAS] No se pudieron cargar: $e');
      if (!mounted) return;
      state = state.copyWith(status: CategoriesAdminStatus.error, error: e);
    }
  }

  void setBusqueda(String value) => state = state.copyWith(busqueda: value);

  void setFiltroEstado(String value) => state = state.copyWith(filtroEstado: value);
}
