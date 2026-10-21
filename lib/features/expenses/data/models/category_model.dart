import '../../domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.idCategoria,
    required super.nombre,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      idCategoria: json['id_categoria'] is int
          ? json['id_categoria'] as int
          : int.tryParse(json['id_categoria']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_categoria': idCategoria,
      'nombre': nombre,
    };
  }
}
