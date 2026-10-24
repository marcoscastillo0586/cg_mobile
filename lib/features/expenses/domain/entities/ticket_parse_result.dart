import 'package:equatable/equatable.dart';
import 'qr_ticket.dart';

class ParsedTicketItem extends Equatable {
  final String nombre;

  /// Importe neto del renglón en centavos.
  final int precioCents;
  final int? idCategoriaSugerida;
  final bool esDudoso;
  final String? motivoDuda;

  const ParsedTicketItem({
    required this.nombre,
    required this.precioCents,
    this.idCategoriaSugerida,
    this.esDudoso = false,
    this.motivoDuda,
  });

  ParsedTicketItem copyWith({
    String? nombre,
    int? precioCents,
    int? idCategoriaSugerida,
    bool? esDudoso,
    String? motivoDuda,
  }) {
    return ParsedTicketItem(
      nombre: nombre ?? this.nombre,
      precioCents: precioCents ?? this.precioCents,
      idCategoriaSugerida: idCategoriaSugerida ?? this.idCategoriaSugerida,
      esDudoso: esDudoso ?? this.esDudoso,
      motivoDuda: motivoDuda ?? this.motivoDuda,
    );
  }

  @override
  List<Object?> get props => [
        nombre,
        precioCents,
        idCategoriaSugerida,
        esDudoso,
        motivoDuda,
      ];
}

class TicketParseResult extends Equatable {
  final String readerName;
  final List<ParsedTicketItem> items;
  /// Total impreso leído del ticket, en centavos (si se pudo leer).
  final int? totalDetectadoCents;
  final List<String> rawTexts;
  final List<String> imagePaths;
  final String diagnosticLog;

  /// Ticket digital leído por QR (servidor). Si está, el egreso se confirma con
  /// `POST /tickets/confirm` (solo con conexión), con PLU, precio unitario y auditoría del ticket.
  final QrTicket? qr;

  const TicketParseResult({
    required this.readerName,
    required this.items,
    this.totalDetectadoCents,
    required this.rawTexts,
    required this.imagePaths,
    this.diagnosticLog = '',
    this.qr,
  });

  int get sumaRenglonesCents => items.fold(0, (acc, item) => acc + item.precioCents);

  /// Diferencia con el total impreso mayor a $ 0,05 (tolerancia de redondeo del comercio).
  bool get tieneDiferenciaTotal => totalDetectadoCents != null && (sumaRenglonesCents - totalDetectadoCents!).abs() > 5;

  bool get tieneRenglonesDudosos => items.any((it) => it.esDudoso);

  @override
  List<Object?> get props => [
        readerName,
        items,
        totalDetectadoCents,
        rawTexts,
        imagePaths,
        diagnosticLog,
        qr,
      ];
}
