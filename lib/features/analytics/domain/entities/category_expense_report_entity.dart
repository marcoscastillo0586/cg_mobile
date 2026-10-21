import 'package:equatable/equatable.dart';

/// Gasto por categoría (GET /reports/by-category). Importes en centavos.
class CategoryExpenseItemEntity extends Equatable {
  final int? idCategoria;
  final String nombre;
  final int montoCents;

  /// Porcentaje sobre el total del período (solo para mostrar).
  final double porcentaje;

  const CategoryExpenseItemEntity({
    required this.idCategoria,
    required this.nombre,
    required this.montoCents,
    required this.porcentaje,
  });

  @override
  List<Object?> get props => [idCategoria, nombre, montoCents, porcentaje];
}

/// Desglose por concepto dentro de las categorías (GET /reports/by-concept-in-categories).
/// Con una categoría la etiqueta es el concepto; con varias, "CATEGORÍA : concepto" (F8.2).
class SubcategoryExpenseItemEntity extends Equatable {
  final String etiqueta;
  final int montoCents;
  final double porcentaje;

  const SubcategoryExpenseItemEntity({required this.etiqueta, required this.montoCents, required this.porcentaje});

  @override
  List<Object?> get props => [etiqueta, montoCents, porcentaje];
}

class CategoryExpenseReportEntity extends Equatable {
  /// `yyyy-MM-dd`.
  final String desde;
  final String hasta;
  final int totalCents;
  final List<CategoryExpenseItemEntity> categorias;
  final List<SubcategoryExpenseItemEntity> subcategorias;

  const CategoryExpenseReportEntity({
    required this.desde,
    required this.hasta,
    required this.totalCents,
    required this.categorias,
    required this.subcategorias,
  });

  @override
  List<Object?> get props => [desde, hasta, totalCents, categorias, subcategorias];
}
