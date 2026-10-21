import 'package:equatable/equatable.dart';

class MovementEntity extends Equatable {
  final int idMovimientoEnc;
  final int tipoMovimiento; // 1: Ingreso, 2: Egreso, 3: Transferencia
  final String conceptoGeneral;
  final String fecha;
  final int idLugar;
  final String lugarNombre;
  final int idCategoria;
  final String categoriaNombre;
  final double monto;
  final int cantidadDetalles;

  const MovementEntity({
    required this.idMovimientoEnc,
    required this.tipoMovimiento,
    required this.conceptoGeneral,
    required this.fecha,
    required this.idLugar,
    required this.lugarNombre,
    required this.idCategoria,
    required this.categoriaNombre,
    required this.monto,
    required this.cantidadDetalles,
  });

  bool get isIncome => tipoMovimiento == 1 || (tipoMovimiento == 3 && monto > 0);
  bool get isExpense => tipoMovimiento == 2 || (tipoMovimiento == 3 && monto < 0);
  bool get isTransfer => tipoMovimiento == 3;

  @override
  List<Object?> get props => [
        idMovimientoEnc,
        tipoMovimiento,
        conceptoGeneral,
        fecha,
        idLugar,
        lugarNombre,
        idCategoria,
        categoriaNombre,
        monto,
        cantidadDetalles,
      ];
}

class MovementsSummaryEntity extends Equatable {
  final double totalIngresos;
  final double totalEgresos;
  final double balancePeriodo;
  final int cantidad;

  const MovementsSummaryEntity({
    required this.totalIngresos,
    required this.totalEgresos,
    required this.balancePeriodo,
    required this.cantidad,
  });

  @override
  List<Object?> get props => [totalIngresos, totalEgresos, balancePeriodo, cantidad];
}
