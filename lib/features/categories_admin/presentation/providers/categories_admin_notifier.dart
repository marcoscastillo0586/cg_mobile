import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../data/repositories/categories_admin_repository_impl.dart';
import '../../domain/entities/category_admin_entity.dart';
import '../../domain/repositories/categories_admin_repository.dart';
import 'categories_admin_state.dart';

final categoriesAdminNotifierProvider =
    StateNotifierProvider.autoDispose<CategoriesAdminNotifier, CategoriesAdminState>((ref) {
  final repository = ref.watch(categoriesAdminRepositoryProvider);
  return CategoriesAdminNotifier(repository, ref);
});

class CategoriesAdminNotifier extends StateNotifier<CategoriesAdminState> {
  final CategoriesAdminRepository _repository;
  final Ref _ref;

  CategoriesAdminNotifier(this._repository, this._ref)
      : super(CategoriesAdminState.initial());

  Future<void> cargarCategorias() async {
    state = state.copyWith(status: CategoriesAdminStatus.loading, clearMessages: true);

    try {
      final res = await _repository.getCategories(todas: true);
      state = state.copyWith(
        status: CategoriesAdminStatus.loaded,
        categorias: res,
      );
    } on Failure catch (e) {
      state = state.copyWith(
        status: CategoriesAdminStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: CategoriesAdminStatus.error,
        errorMessage: 'Error al consultar categorías: $e',
      );
    }
  }

  void setBusqueda(String query) {
    state = state.copyWith(busqueda: query);
  }

  void setFiltroEstado(String filtro) {
    state = state.copyWith(filtroEstado: filtro);
  }

  Future<bool> crearCategoria({required String nombre}) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final nueva = await _repository.createCategory(nombre: nombre);
      final actualizadas = [nueva, ...state.categorias];
      state = state.copyWith(
        isSaving: false,
        categorias: actualizadas,
        successMessage: 'Categoría "${nueva.nombre}" creada con éxito',
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Error al crear categoría: $e');
      return false;
    }
  }

  Future<bool> editarCategoria({
    required int idCategoria,
    required String nombre,
    required bool activa,
  }) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final editada = await _repository.updateCategory(
        idCategoria: idCategoria,
        nombre: nombre,
        activa: activa,
      );

      final actualizadas = state.categorias.map((c) {
        if (c.idCategoria == idCategoria) {
          return c.copyWith(nombre: editada.nombre, activa: editada.activa);
        }
        return c;
      }).toList();

      state = state.copyWith(
        isSaving: false,
        categorias: actualizadas,
        successMessage: 'Categoría "${editada.nombre}" actualizada',
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Error al actualizar categoría: $e');
      return false;
    }
  }

  Future<bool> toggleEstado({
    required int idCategoria,
    required bool nuevaActiva,
  }) async {
    try {
      final ok = await _repository.toggleCategoryStatus(
        idCategoria: idCategoria,
        activa: nuevaActiva,
      );

      if (ok) {
        final actualizadas = state.categorias.map((c) {
          if (c.idCategoria == idCategoria) {
            return c.copyWith(activa: nuevaActiva);
          }
          return c;
        }).toList();

        state = state.copyWith(
          categorias: actualizadas,
          successMessage: nuevaActiva ? 'Categoría activada' : 'Categoría desactivada',
        );

        unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> eliminarCategoria(int idCategoria) async {
    state = state.copyWith(isSaving: true, clearMessages: true);

    try {
      final res = await _repository.deleteCategory(idCategoria: idCategoria);

      List<CategoryAdminEntity> actualizadas;
      if (res.eliminadoFisico) {
        actualizadas = state.categorias.where((c) => c.idCategoria != idCategoria).toList();
      } else {
        actualizadas = state.categorias.map((c) {
          if (c.idCategoria == idCategoria) {
            return c.copyWith(activa: false);
          }
          return c;
        }).toList();
      }

      state = state.copyWith(
        isSaving: false,
        categorias: actualizadas,
        successMessage: res.mensaje,
      );

      unawaited(_ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
      return true;
    } on Failure catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Error al eliminar categoría: $e');
      return false;
    }
  }
}
