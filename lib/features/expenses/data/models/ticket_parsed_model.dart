import '../../domain/entities/ticket_parsed_entity.dart';

class TicketProductItemModel extends TicketProductItemEntity {
  const TicketProductItemModel({
    required super.nombre,
    required super.precio,
    super.idCategoriaSugerida,
  });

  factory TicketProductItemModel.fromJson(Map<String, dynamic> json) {
    return TicketProductItemModel(
      nombre: json['nombre'] as String? ?? 'Producto',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      idCategoriaSugerida: json['id_categoria'] is int
          ? json['id_categoria'] as int
          : int.tryParse(json['id_categoria']?.toString() ?? ''),
    );
  }
}

class TicketParsedModel extends TicketParsedEntity {
  const TicketParsedModel({
    required super.total,
    required super.items,
  });

  factory TicketParsedModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsParsed = rawItems
        .map((e) => TicketProductItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return TicketParsedModel(
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      items: itemsParsed,
    );
  }
}
