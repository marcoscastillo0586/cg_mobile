import 'package:equatable/equatable.dart';

class MovementItemDetailEntity extends Equatable {
  final int idMovimientoDet;
  final int idLugar;
  final String lugarNombre;
  final int idCategoria;
  final String categoriaNombre;
  final String concepto;
  final double monto;
  final int signo;
  final double cantidad;
  final String codigo;
  final String img;

  const MovementItemDetailEntity({
    required this.idMovimientoDet,
    required this.idLugar,
    required this.lugarNombre,
    required this.idCategoria,
    required this.categoriaNombre,
    required this.concepto,
    required this.monto,
    required this.signo,
    required this.cantidad,
    required this.codigo,
    this.img = '',
  });

  @override
  List<Object?> get props => [
        idMovimientoDet,
        idLugar,
        lugarNombre,
        idCategoria,
        categoriaNombre,
        concepto,
        monto,
        signo,
        cantidad,
        codigo,
        img,
      ];
}

class MovementDetailEntity extends Equatable {
  final int idMovimientoEnc;
  final int tipoMovimiento;
  final String conceptoGeneral;
  final String fecha;
  final double montoTotal;
  final int idLugarOrigen;
  final int idLugarDestino;
  final List<MovementItemDetailEntity> detalles;

  const MovementDetailEntity({
    required this.idMovimientoEnc,
    required this.tipoMovimiento,
    required this.conceptoGeneral,
    required this.fecha,
    required this.montoTotal,
    required this.idLugarOrigen,
    required this.idLugarDestino,
    required this.detalles,
  });

  bool get isIncome => tipoMovimiento == 1;
  bool get isExpense => tipoMovimiento == 2;
  bool get isTransfer => tipoMovimiento == 3;

  @override
  List<Object?> get props => [
        idMovimientoEnc,
        tipoMovimiento,
        conceptoGeneral,
        fecha,
        montoTotal,
        idLugarOrigen,
        idLugarDestino,
        detalles,
      ];
}
