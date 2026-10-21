import 'package:equatable/equatable.dart';

class CategoryAdminEntity extends Equatable {
  final int idCategoria;
  final String nombre;
  final bool activa;
  final int cantidadMovimientos;
  final double totalGastado;
  final String? syncId;

  const CategoryAdminEntity({
    required this.idCategoria,
    required this.nombre,
    required this.activa,
    this.cantidadMovimientos = 0,
    this.totalGastado = 0.0,
    this.syncId,
  });

  CategoryAdminEntity copyWith({
    int? idCategoria,
    String? nombre,
    bool? activa,
    int? cantidadMovimientos,
    double? totalGastado,
    String? syncId,
  }) {
    return CategoryAdminEntity(
      idCategoria: idCategoria ?? this.idCategoria,
      nombre: nombre ?? this.nombre,
      activa: activa ?? this.activa,
      cantidadMovimientos: cantidadMovimientos ?? this.cantidadMovimientos,
      totalGastado: totalGastado ?? this.totalGastado,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  List<Object?> get props => [
        idCategoria,
        nombre,
        activa,
        cantidadMovimientos,
        totalGastado,
        syncId,
      ];
}
