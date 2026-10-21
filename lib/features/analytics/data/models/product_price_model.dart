import '../../domain/entities/product_price_entity.dart';

class ProductPriceItemModel extends ProductPriceItemEntity {
  const ProductPriceItemModel({
    required super.concepto,
    required super.plu,
    required super.totalCompras,
    required super.ultimoPrecio,
    required super.primerPrecio,
    required super.precioMinimo,
    required super.precioMaximo,
    required super.variacionPorcentaje,
    required super.ultimaFecha,
    required super.primeraFecha,
    required super.ultimoLugar,
  });

  factory ProductPriceItemModel.fromJson(Map<String, dynamic> json) {
    return ProductPriceItemModel(
      concepto: json['concepto'] as String? ?? '',
      plu: json['plu'] as String? ?? '',
      totalCompras: (json['total_compras'] as num?)?.toInt() ?? 0,
      ultimoPrecio: (json['ultimo_precio'] as num?)?.toDouble() ?? 0.0,
      primerPrecio: (json['primer_precio'] as num?)?.toDouble() ?? 0.0,
      precioMinimo: (json['precio_minimo'] as num?)?.toDouble() ?? 0.0,
      precioMaximo: (json['precio_maximo'] as num?)?.toDouble() ?? 0.0,
      variacionPorcentaje: (json['variacion_porcentaje'] as num?)?.toDouble() ?? 0.0,
      ultimaFecha: json['ultima_fecha'] as String? ?? '',
      primeraFecha: json['primera_fecha'] as String? ?? '',
      ultimoLugar: json['ultimo_lugar'] as String? ?? '',
    );
  }
}

class ProductPurchaseHistoryItemModel extends ProductPurchaseHistoryItemEntity {
  const ProductPurchaseHistoryItemModel({
    required super.idMovimientoEnc,
    required super.fechaHora,
    required super.fecha,
    required super.lugarNombre,
    required super.categoriaNombre,
    required super.concepto,
    required super.precioUnitario,
    required super.cantidad,
    required super.montoTotal,
  });

  factory ProductPurchaseHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return ProductPurchaseHistoryItemModel(
      idMovimientoEnc: (json['id_movimiento_enc'] as num?)?.toInt() ?? 0,
      fechaHora: json['fecha_hora'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      lugarNombre: json['lugar_nombre'] as String? ?? '',
      categoriaNombre: json['categoria_nombre'] as String? ?? '',
      concepto: json['concepto'] as String? ?? '',
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductPriceHistoryModel extends ProductPriceHistoryEntity {
  const ProductPriceHistoryModel({
    required super.concepto,
    required super.cantidadCompras,
    required super.precioActual,
    required super.precioInicial,
    required super.precioMinimo,
    required super.precioMaximo,
    required super.aumentoPorcentaje,
    required List<ProductPurchaseHistoryItemModel> super.historial,
  });

  factory ProductPriceHistoryModel.fromJson(Map<String, dynamic> json) {
    final rawHistorial = json['historial'] as List<dynamic>? ?? [];
    final items = rawHistorial
        .map((e) => ProductPurchaseHistoryItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ProductPriceHistoryModel(
      concepto: json['concepto'] as String? ?? '',
      cantidadCompras: (json['cantidad_compras'] as num?)?.toInt() ?? items.length,
      precioActual: (json['precio_actual'] as num?)?.toDouble() ?? 0.0,
      precioInicial: (json['precio_inicial'] as num?)?.toDouble() ?? 0.0,
      precioMinimo: (json['precio_minimo'] as num?)?.toDouble() ?? 0.0,
      precioMaximo: (json['precio_maximo'] as num?)?.toDouble() ?? 0.0,
      aumentoPorcentaje: (json['aumento_porcentaje'] as num?)?.toDouble() ?? 0.0,
      historial: items,
    );
  }
}

class PriceComparisonItemModel extends PriceComparisonItemEntity {
  const PriceComparisonItemModel({
    required super.producto,
    required super.precio1,
    required super.precio2,
    required super.diferencia,
    required super.porcentaje,
    required super.cantidadPeriodo2,
  });

  factory PriceComparisonItemModel.fromJson(Map<String, dynamic> json) {
    return PriceComparisonItemModel(
      producto: json['producto'] as String? ?? '',
      precio1: (json['precio1'] as num?)?.toDouble() ?? 0.0,
      precio2: (json['precio2'] as num?)?.toDouble() ?? 0.0,
      diferencia: (json['diferencia'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      cantidadPeriodo2: (json['cantidad_periodo2'] as num?)?.toInt() ?? 0,
    );
  }
}

class PriceComparisonResultModel extends PriceComparisonResultEntity {
  const PriceComparisonResultModel({
    required super.productosComunes,
    required super.inflacionPromedio,
    required super.productosAumentaron,
    required List<PriceComparisonItemModel> super.comparativa,
  });

  factory PriceComparisonResultModel.fromJson(Map<String, dynamic> json) {
    final rawTotales = json['totales'] as Map<String, dynamic>? ?? {};
    final rawComp = json['comparativa'] as List<dynamic>? ?? [];

    final list = rawComp
        .map((e) => PriceComparisonItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PriceComparisonResultModel(
      productosComunes: (rawTotales['productos_comunes'] as num?)?.toInt() ?? list.length,
      inflacionPromedio: (rawTotales['inflacion_promedio'] as num?)?.toDouble() ?? 0.0,
      productosAumentaron: (rawTotales['productos_aumentaron'] as num?)?.toInt() ?? 0,
      comparativa: list,
    );
  }
}
