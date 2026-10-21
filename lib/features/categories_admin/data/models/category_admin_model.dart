import '../../domain/entities/category_admin_entity.dart';

class CategoryAdminModel extends CategoryAdminEntity {
  const CategoryAdminModel({
    required super.idCategoria,
    required super.nombre,
    required super.activa,
    required super.cantidadMovimientos,
    required super.totalGastado,
  });

  factory CategoryAdminModel.fromJson(Map<String, dynamic> json) {
    return CategoryAdminModel(
      idCategoria: (json['id_categoria'] as num).toInt(),
      nombre: (json['nombre'] as String? ?? '').trim(),
      activa: json['activa'] as bool? ?? true,
      cantidadMovimientos: (json['cantidad_movimientos'] as num?)?.toInt() ?? 0,
      totalGastado: (json['total_gastado'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_categoria': idCategoria,
      'nombre': nombre,
      'activa': activa,
      'cantidad_movimientos': cantidadMovimientos,
      'total_gastado': totalGastado,
    };
  }
}
