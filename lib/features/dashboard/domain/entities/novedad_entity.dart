import 'package:equatable/equatable.dart';

enum NovedadTipo {
  cerca,      // >= 75% y < 100% (Naranja)
  alcanzado,  // >= 100% (Rojo)
  vencido,    // hoy > hasta (Azul AppColors.primary)
}

class NovedadEntity extends Equatable {
  final String idKey;
  final int idLimiteGasto;
  final String titulo;
  final NovedadTipo tipo;
  final int porcentaje; // Truncado entero hacia abajo
  final DateTime desde;
  final DateTime hasta;
  final bool vista;

  const NovedadEntity({
    required this.idKey,
    required this.idLimiteGasto,
    required this.titulo,
    required this.tipo,
    required this.porcentaje,
    required this.desde,
    required this.hasta,
    this.vista = false,
  });

  NovedadEntity copyWith({bool? vista}) {
    return NovedadEntity(
      idKey: idKey,
      idLimiteGasto: idLimiteGasto,
      titulo: titulo,
      tipo: tipo,
      porcentaje: porcentaje,
      desde: desde,
      hasta: hasta,
      vista: vista ?? this.vista,
    );
  }

  @override
  List<Object?> get props => [
        idKey,
        idLimiteGasto,
        titulo,
        tipo,
        porcentaje,
        desde,
        hasta,
        vista,
      ];
}
