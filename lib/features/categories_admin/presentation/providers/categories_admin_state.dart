import 'package:equatable/equatable.dart';
import '../../domain/category_item.dart';

enum CategoriesAdminStatus { initial, loading, loaded, error }

class CategoriesAdminState extends Equatable {
  final CategoriesAdminStatus status;
  final List<CategoryItem> categorias;
  final String busqueda;
  final String filtroEstado; // 'todas', 'activas', 'inactivas'
  final Object? error;

  const CategoriesAdminState({
    required this.status,
    required this.categorias,
    required this.busqueda,
    required this.filtroEstado,
    this.error,
  });

  factory CategoriesAdminState.initial() => const CategoriesAdminState(
        status: CategoriesAdminStatus.initial,
        categorias: [],
        busqueda: '',
        filtroEstado: 'todas',
      );

  List<CategoryItem> get categoriasFiltradas {
    var lista = categorias;
    if (filtroEstado == 'activas') lista = lista.where((c) => c.active).toList();
    if (filtroEstado == 'inactivas') lista = lista.where((c) => !c.active).toList();
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) lista = lista.where((c) => c.name.toLowerCase().contains(q)).toList();
    return lista;
  }

  int get activasCount => categorias.where((c) => c.active).length;
  int get inactivasCount => categorias.where((c) => !c.active).length;

  CategoriesAdminState copyWith({
    CategoriesAdminStatus? status,
    List<CategoryItem>? categorias,
    String? busqueda,
    String? filtroEstado,
    Object? error,
    bool clearError = false,
  }) {
    return CategoriesAdminState(
      status: status ?? this.status,
      categorias: categorias ?? this.categorias,
      busqueda: busqueda ?? this.busqueda,
      filtroEstado: filtroEstado ?? this.filtroEstado,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, categorias, busqueda, filtroEstado, error];
}
