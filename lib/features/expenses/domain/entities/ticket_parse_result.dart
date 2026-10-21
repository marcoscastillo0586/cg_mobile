import 'package:equatable/equatable.dart';

class ParsedTicketItem extends Equatable {
  final String nombre;
  final double precio;
  final int? idCategoriaSugerida;
  final bool esDudoso;
  final String? motivoDuda;

  const ParsedTicketItem({
    required this.nombre,
    required this.precio,
    this.idCategoriaSugerida,
    this.esDudoso = false,
    this.motivoDuda,
  });

  ParsedTicketItem copyWith({
    String? nombre,
    double? precio,
    int? idCategoriaSugerida,
    bool? esDudoso,
    String? motivoDuda,
  }) {
    return ParsedTicketItem(
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      idCategoriaSugerida: idCategoriaSugerida ?? this.idCategoriaSugerida,
      esDudoso: esDudoso ?? this.esDudoso,
      motivoDuda: motivoDuda ?? this.motivoDuda,
    );
  }

  @override
  List<Object?> get props => [
        nombre,
        precio,
        idCategoriaSugerida,
        esDudoso,
        motivoDuda,
      ];
}

class TicketParseResult extends Equatable {
  final String readerName;
  final List<ParsedTicketItem> items;
  final double? totalDetectado;
  final List<String> rawTexts;
  final List<String> imagePaths;
  final String diagnosticLog;

  const TicketParseResult({
    required this.readerName,
    required this.items,
    this.totalDetectado,
    required this.rawTexts,
    required this.imagePaths,
    this.diagnosticLog = '',
  });

  double get sumaRenglones => items.fold(0.0, (acc, item) => acc + item.precio);

  bool get tieneDiferenciaTotal =>
      totalDetectado != null && (sumaRenglones - totalDetectado!).abs() > 0.05;

  bool get tieneRenglonesDudosos => items.any((it) => it.esDudoso);

  @override
  List<Object?> get props => [
        readerName,
        items,
        totalDetectado,
        rawTexts,
        imagePaths,
        diagnosticLog,
      ];
}
