import 'package:equatable/equatable.dart';
import '../../domain/entities/category_admin_entity.dart';

enum CategoriesAdminStatus { initial, loading, loaded, error }

class CategoriesAdminState extends Equatable {
  final CategoriesAdminStatus status;
  final List<CategoryAdminEntity> categorias;
  final String busqueda;
  final String filtroEstado; // 'todas', 'activas', 'inactivas'
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const CategoriesAdminState({
    required this.status,
    required this.categorias,
    required this.busqueda,
    required this.filtroEstado,
    required this.isSaving,
    this.errorMessage,
    this.successMessage,
  });

  factory CategoriesAdminState.initial() {
    return const CategoriesAdminState(
      status: CategoriesAdminStatus.initial,
      categorias: [],
      busqueda: '',
      filtroEstado: 'todas',
      isSaving: false,
    );
  }

  List<CategoryAdminEntity> get categoriasFiltradas {
    var lista = categorias;
    if (filtroEstado == 'activas') {
      lista = lista.where((c) => c.activa).toList();
    } else if (filtroEstado == 'inactivas') {
      lista = lista.where((c) => !c.activa).toList();
    }
    if (busqueda.trim().isNotEmpty) {
      final query = busqueda.trim().toLowerCase();
      lista = lista.where((c) => c.nombre.toLowerCase().contains(query)).toList();
    }
    return lista;
  }

  int get activasCount => categorias.where((c) => c.activa).length;
  int get inactivasCount => categorias.where((c) => !c.activa).length;

  CategoriesAdminState copyWith({
    CategoriesAdminStatus? status,
    List<CategoryAdminEntity>? categorias,
    String? busqueda,
    String? filtroEstado,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CategoriesAdminState(
      status: status ?? this.status,
      categorias: categorias ?? this.categorias,
      busqueda: busqueda ?? this.busqueda,
      filtroEstado: filtroEstado ?? this.filtroEstado,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        categorias,
        busqueda,
        filtroEstado,
        isSaving,
        errorMessage,
        successMessage,
      ];
}
