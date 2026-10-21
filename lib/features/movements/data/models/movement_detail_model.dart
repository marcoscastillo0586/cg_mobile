import '../../domain/entities/movement_detail_entity.dart';

class MovementItemDetailModel extends MovementItemDetailEntity {
  const MovementItemDetailModel({
    required super.idMovimientoDet,
    required super.idLugar,
    required super.lugarNombre,
    required super.idCategoria,
    required super.categoriaNombre,
    required super.concepto,
    required super.monto,
    required super.signo,
    required super.cantidad,
    required super.codigo,
    required super.img,
  });

  factory MovementItemDetailModel.fromJson(Map<String, dynamic> json) {
    final rawMonto = json['monto']?.toString() ?? '0';
    final parsedMonto = double.tryParse(rawMonto.replaceAll(',', '.')) ?? 0.0;

    return MovementItemDetailModel(
      idMovimientoDet: int.tryParse(json['id_movimiento_det']?.toString() ?? '0') ?? 0,
      idLugar: int.tryParse(json['id_lugar']?.toString() ?? '0') ?? 0,
      lugarNombre: (json['lugar_nombre'] ?? json['nombre_lugar'] ?? json['lugar'] ?? '').toString(),
      idCategoria: int.tryParse(json['id_categoria']?.toString() ?? '0') ?? 0,
      categoriaNombre: (json['categoria_nombre'] ?? json['nombre_categoria'] ?? json['categoria'] ?? 'General').toString(),
      concepto: (json['concepto'] ?? json['descripcion'] ?? json['nombre'] ?? '').toString(),
      monto: parsedMonto.abs(),
      signo: int.tryParse(json['signo']?.toString() ?? '1') ?? 1,
      cantidad: double.tryParse(json['cantidad']?.toString() ?? '1') ?? 1.0,
      codigo: (json['codigo'] ?? '').toString(),
      img: (json['img'] ?? '').toString().trim(),
    );
  }
}

class MovementDetailModel extends MovementDetailEntity {
  const MovementDetailModel({
    required super.idMovimientoEnc,
    required super.tipoMovimiento,
    required super.conceptoGeneral,
    required super.fecha,
    required super.montoTotal,
    required super.idLugarOrigen,
    required super.idLugarDestino,
    required List<MovementItemDetailModel> super.detalles,
  });

  factory MovementDetailModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> dataMap = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawDetalles = (dataMap['detalles'] ?? dataMap['items'] ?? dataMap['renglones']) as List<dynamic>? ?? [];
    final detalles = rawDetalles.map((e) {
      final map = e is Map<String, dynamic>
          ? e
          : Map<String, dynamic>.from(e as Map);
      return MovementItemDetailModel.fromJson(map);
    }).toList();

    final rawMontoTotal = dataMap['monto_total']?.toString() ?? '0';

    return MovementDetailModel(
      idMovimientoEnc: int.tryParse(dataMap['id_movimiento_enc']?.toString() ?? '0') ?? 0,
      tipoMovimiento: int.tryParse(dataMap['tipo_movimiento']?.toString() ?? '2') ?? 2,
      conceptoGeneral: (dataMap['concepto_general'] ?? '').toString(),
      fecha: (dataMap['fecha'] ?? '').toString(),
      montoTotal: double.tryParse(rawMontoTotal.replaceAll(',', '.')) ?? 0.0,
      idLugarOrigen: int.tryParse(dataMap['id_lugar_origen']?.toString() ?? '0') ?? 0,
      idLugarDestino: int.tryParse(dataMap['id_lugar_destino']?.toString() ?? '0') ?? 0,
      detalles: detalles,
    );
  }
}
