import 'package:equatable/equatable.dart';

class TicketProductItemEntity extends Equatable {
  final String nombre;
  final double precio;
  final int? idCategoriaSugerida;

  const TicketProductItemEntity({
    required this.nombre,
    required this.precio,
    this.idCategoriaSugerida,
  });

  @override
  List<Object?> get props => [nombre, precio, idCategoriaSugerida];
}

class TicketParsedEntity extends Equatable {
  final double total;
  final List<TicketProductItemEntity> items;

  const TicketParsedEntity({
    required this.total,
    required this.items,
  });

  @override
  List<Object?> get props => [total, items];
}
