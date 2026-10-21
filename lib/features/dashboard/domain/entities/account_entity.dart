import 'package:equatable/equatable.dart';

class AccountEntity extends Equatable {
  final int idLugar;
  final String nombre;
  final int tipoMoneda; // 1: ARS, 2: USD
  final String simboloMoneda;
  final double montoOriginal;
  final double montoPesos;
  final double cotizacion;
  final String? imgUrl;
  final String? imgBase64;

  const AccountEntity({
    required this.idLugar,
    required this.nombre,
    required this.tipoMoneda,
    required this.simboloMoneda,
    required this.montoOriginal,
    required this.montoPesos,
    required this.cotizacion,
    this.imgUrl,
    this.imgBase64,
  });

  bool get isUSD => tipoMoneda == 2;

  @override
  List<Object?> get props => [
        idLugar,
        nombre,
        tipoMoneda,
        simboloMoneda,
        montoOriginal,
        montoPesos,
        cotizacion,
        imgUrl,
        imgBase64,
      ];
}
