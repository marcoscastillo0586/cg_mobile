import 'package:equatable/equatable.dart';

/// Producto comprado con su evolución de precio (GET /reports/products). Centavos.
class ProductPriceItemEntity extends Equatable {
  final String concepto;
  final String? plu;
  final int totalCompras;
  final int ultimoPrecioCents;
  final int primerPrecioCents;
  final int precioMinimoCents;
  final int precioMaximoCents;
  final num variacionPorcentaje;
  final String ultimaFecha;
  final String primeraFecha;
  final String ultimoLugar;

  const ProductPriceItemEntity({
    required this.concepto,
    required this.plu,
    required this.totalCompras,
    required this.ultimoPrecioCents,
    required this.primerPrecioCents,
    required this.precioMinimoCents,
    required this.precioMaximoCents,
    required this.variacionPorcentaje,
    required this.ultimaFecha,
    required this.primeraFecha,
    required this.ultimoLugar,
  });

  bool get haAumentado => variacionPorcentaje > 0;

  @override
  List<Object?> get props => [
        concepto,
        plu,
        totalCompras,
        ultimoPrecioCents,
        primerPrecioCents,
        precioMinimoCents,
        precioMaximoCents,
        variacionPorcentaje,
        ultimaFecha,
        primeraFecha,
        ultimoLugar,
      ];
}

class ProductPurchaseHistoryItemEntity extends Equatable {
  final int idMovimientoEnc;

  /// `yyyy-MM-dd HH:mm:ss`.
  final String fechaHora;
  final String lugarNombre;
  final String? categoriaNombre;
  final String concepto;
  final int precioUnitarioCents;
  final int montoTotalCents;

  const ProductPurchaseHistoryItemEntity({
    required this.idMovimientoEnc,
    required this.fechaHora,
    required this.lugarNombre,
    required this.categoriaNombre,
    required this.concepto,
    required this.precioUnitarioCents,
    required this.montoTotalCents,
  });

  @override
  List<Object?> get props => [idMovimientoEnc, fechaHora, lugarNombre, categoriaNombre, concepto, precioUnitarioCents, montoTotalCents];
}

/// Historial de un producto (GET /reports/product-history).
class ProductPriceHistoryEntity extends Equatable {
  final String concepto;
  final int cantidadCompras;
  final int precioActualCents;
  final int precioInicialCents;
  final int precioMinimoCents;
  final int precioMaximoCents;
  final num aumentoPorcentaje;
  final List<ProductPurchaseHistoryItemEntity> historial;

  const ProductPriceHistoryEntity({
    required this.concepto,
    required this.cantidadCompras,
    required this.precioActualCents,
    required this.precioInicialCents,
    required this.precioMinimoCents,
    required this.precioMaximoCents,
    required this.aumentoPorcentaje,
    required this.historial,
  });

  @override
  List<Object?> get props => [
        concepto,
        cantidadCompras,
        precioActualCents,
        precioInicialCents,
        precioMinimoCents,
        precioMaximoCents,
        aumentoPorcentaje,
        historial,
      ];
}

/// Inflación de productos idénticos por PLU entre dos períodos (GET /reports/compare-products).
class PriceComparisonItemEntity extends Equatable {
  final String plu;
  final String producto;
  final int precio1Cents;
  final int precio2Cents;
  final int diferenciaCents;
  final num porcentaje;
  final num cantidadPeriodo2;

  const PriceComparisonItemEntity({
    required this.plu,
    required this.producto,
    required this.precio1Cents,
    required this.precio2Cents,
    required this.diferenciaCents,
    required this.porcentaje,
    required this.cantidadPeriodo2,
  });

  @override
  List<Object?> get props => [plu, producto, precio1Cents, precio2Cents, diferenciaCents, porcentaje, cantidadPeriodo2];
}

class PriceComparisonResultEntity extends Equatable {
  final int productosComunes;
  final num inflacionPromedio;
  final List<PriceComparisonItemEntity> comparativa;

  const PriceComparisonResultEntity({required this.productosComunes, required this.inflacionPromedio, required this.comparativa});

  int get productosAumentaron => comparativa.where((c) => c.porcentaje > 0).length;

  @override
  List<Object?> get props => [productosComunes, inflacionPromedio, comparativa];
}
