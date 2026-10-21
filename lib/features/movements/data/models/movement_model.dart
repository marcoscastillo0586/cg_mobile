import '../../domain/entities/movement_entity.dart';

class MovementModel extends MovementEntity {
  const MovementModel({
    required super.idMovimientoEnc,
    required super.tipoMovimiento,
    required super.conceptoGeneral,
    required super.fecha,
    required super.idLugar,
    required super.lugarNombre,
    required super.idCategoria,
    required super.categoriaNombre,
    required super.monto,
    required super.cantidadDetalles,
  });

  factory MovementModel.fromJson(Map<String, dynamic> json) {
    return MovementModel(
      idMovimientoEnc: json['id_movimiento_enc'] is int
          ? json['id_movimiento_enc'] as int
          : int.tryParse(json['id_movimiento_enc']?.toString() ?? '0') ?? 0,
      tipoMovimiento: json['tipo_movimiento'] is int
          ? json['tipo_movimiento'] as int
          : int.tryParse(json['tipo_movimiento']?.toString() ?? '2') ?? 2,
      conceptoGeneral: json['concepto_general'] as String? ?? 'Movimiento',
      fecha: json['fecha'] as String? ?? '',
      idLugar: json['id_lugar'] is int
          ? json['id_lugar'] as int
          : int.tryParse(json['id_lugar']?.toString() ?? '0') ?? 0,
      lugarNombre: json['lugar_nombre'] as String? ?? '',
      idCategoria: json['id_categoria'] is int
          ? json['id_categoria'] as int
          : int.tryParse(json['id_categoria']?.toString() ?? '0') ?? 0,
      categoriaNombre: json['categoria_nombre'] as String? ?? 'General',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      cantidadDetalles: json['cantidad_detalles'] is int
          ? json['cantidad_detalles'] as int
          : int.tryParse(json['cantidad_detalles']?.toString() ?? '1') ?? 1,
    );
  }
}

class MovementsSummaryModel extends MovementsSummaryEntity {
  const MovementsSummaryModel({
    required super.totalIngresos,
    required super.totalEgresos,
    required super.balancePeriodo,
    required super.cantidad,
  });

  factory MovementsSummaryModel.fromJson(Map<String, dynamic> json) {
    return MovementsSummaryModel(
      totalIngresos: (json['total_ingresos'] as num?)?.toDouble() ?? 0.0,
      totalEgresos: (json['total_egresos'] as num?)?.toDouble() ?? 0.0,
      balancePeriodo: (json['balance_periodo'] as num?)?.toDouble() ?? 0.0,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}
