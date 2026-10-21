import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final int idCategoria;
  final String nombre;

  const CategoryEntity({
    required this.idCategoria,
    required this.nombre,
  });

  @override
  List<Object?> get props => [idCategoria, nombre];
}
