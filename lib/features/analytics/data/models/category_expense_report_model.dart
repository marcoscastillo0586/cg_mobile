import '../../domain/entities/category_expense_report_entity.dart';

class CategoryExpenseItemModel extends CategoryExpenseItemEntity {
  const CategoryExpenseItemModel({
    required super.idCategoria,
    required super.nombre,
    required super.monto,
    required super.porcentaje,
    required super.cantidadMovimientos,
  });

  factory CategoryExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return CategoryExpenseItemModel(
      idCategoria: (json['id_categoria'] as num?)?.toInt() ?? 0,
      nombre: json['nombre'] as String? ?? 'General',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      cantidadMovimientos: (json['cantidad_movimientos'] as num?)?.toInt() ?? 0,
    );
  }
}

class SubcategoryExpenseItemModel extends SubcategoryExpenseItemEntity {
  const SubcategoryExpenseItemModel({
    required super.concepto,
    required super.categoria,
    required super.monto,
    required super.porcentaje,
    required super.cantidad,
  });

  factory SubcategoryExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryExpenseItemModel(
      concepto: json['concepto'] as String? ?? 'Varios',
      categoria: json['categoria'] as String? ?? 'General',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}

class CategoryExpenseReportModel extends CategoryExpenseReportEntity {
  const CategoryExpenseReportModel({
    required super.desde,
    required super.hasta,
    required super.totalGastos,
    required super.categorias,
    required super.subcategorias,
  });

  factory CategoryExpenseReportModel.fromJson(Map<String, dynamic> json) {
    final catList = (json['categorias'] as List<dynamic>?)
            ?.map((e) => CategoryExpenseItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final subList = (json['subcategorias'] as List<dynamic>?)
            ?.map((e) => SubcategoryExpenseItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CategoryExpenseReportModel(
      desde: json['desde'] as String? ?? '',
      hasta: json['hasta'] as String? ?? '',
      totalGastos: (json['total_gastos'] as num?)?.toDouble() ?? 0.0,
      categorias: catList,
      subcategorias: subList,
    );
  }
}
