import 'package:equatable/equatable.dart';

class CategoryExpenseItemEntity extends Equatable {
  final int idCategoria;
  final String nombre;
  final double monto;
  final double porcentaje;
  final int cantidadMovimientos;

  const CategoryExpenseItemEntity({
    required this.idCategoria,
    required this.nombre,
    required this.monto,
    required this.porcentaje,
    required this.cantidadMovimientos,
  });

  @override
  List<Object?> get props => [idCategoria, nombre, monto, porcentaje, cantidadMovimientos];
}

class SubcategoryExpenseItemEntity extends Equatable {
  final String concepto;
  final String categoria;
  final double monto;
  final double porcentaje;
  final int cantidad;

  const SubcategoryExpenseItemEntity({
    required this.concepto,
    required this.categoria,
    required this.monto,
    required this.porcentaje,
    required this.cantidad,
  });

  @override
  List<Object?> get props => [concepto, categoria, monto, porcentaje, cantidad];
}

class CategoryExpenseReportEntity extends Equatable {
  final String desde;
  final String hasta;
  final double totalGastos;
  final List<CategoryExpenseItemEntity> categorias;
  final List<SubcategoryExpenseItemEntity> subcategorias;

  const CategoryExpenseReportEntity({
    required this.desde,
    required this.hasta,
    required this.totalGastos,
    required this.categorias,
    required this.subcategorias,
  });

  @override
  List<Object?> get props => [desde, hasta, totalGastos, categorias, subcategorias];
}
