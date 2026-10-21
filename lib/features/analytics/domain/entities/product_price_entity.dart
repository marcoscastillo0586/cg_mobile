import 'package:equatable/equatable.dart';

class ProductPriceItemEntity extends Equatable {
  final String concepto;
  final String plu;
  final int totalCompras;
  final double ultimoPrecio;
  final double primerPrecio;
  final double precioMinimo;
  final double precioMaximo;
  final double variacionPorcentaje;
  final String ultimaFecha;
  final String primeraFecha;
  final String ultimoLugar;

  const ProductPriceItemEntity({
    required this.concepto,
    required this.plu,
    required this.totalCompras,
    required this.ultimoPrecio,
    required this.primerPrecio,
    required this.precioMinimo,
    required this.precioMaximo,
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
        ultimoPrecio,
        primerPrecio,
        precioMinimo,
        precioMaximo,
        variacionPorcentaje,
        ultimaFecha,
        primeraFecha,
        ultimoLugar,
      ];
}

class ProductPurchaseHistoryItemEntity extends Equatable {
  final int idMovimientoEnc;
  final String fechaHora;
  final String fecha;
  final String lugarNombre;
  final String categoriaNombre;
  final String concepto;
  final double precioUnitario;
  final double cantidad;
  final double montoTotal;

  const ProductPurchaseHistoryItemEntity({
    required this.idMovimientoEnc,
    required this.fechaHora,
    required this.fecha,
    required this.lugarNombre,
    required this.categoriaNombre,
    required this.concepto,
    required this.precioUnitario,
    required this.cantidad,
    required this.montoTotal,
  });

  @override
  List<Object?> get props => [
        idMovimientoEnc,
        fechaHora,
        fecha,
        lugarNombre,
        categoriaNombre,
        concepto,
        precioUnitario,
        cantidad,
        montoTotal,
      ];
}

class ProductPriceHistoryEntity extends Equatable {
  final String concepto;
  final int cantidadCompras;
  final double precioActual;
  final double precioInicial;
  final double precioMinimo;
  final double precioMaximo;
  final double aumentoPorcentaje;
  final List<ProductPurchaseHistoryItemEntity> historial;

  const ProductPriceHistoryEntity({
    required this.concepto,
    required this.cantidadCompras,
    required this.precioActual,
    required this.precioInicial,
    required this.precioMinimo,
    required this.precioMaximo,
    required this.aumentoPorcentaje,
    required this.historial,
  });

  @override
  List<Object?> get props => [
        concepto,
        cantidadCompras,
        precioActual,
        precioInicial,
        precioMinimo,
        precioMaximo,
        aumentoPorcentaje,
        historial,
      ];
}

class PriceComparisonItemEntity extends Equatable {
  final String producto;
  final double precio1;
  final double precio2;
  final double diferencia;
  final double porcentaje;
  final int cantidadPeriodo2;

  const PriceComparisonItemEntity({
    required this.producto,
    required this.precio1,
    required this.precio2,
    required this.diferencia,
    required this.porcentaje,
    required this.cantidadPeriodo2,
  });

  @override
  List<Object?> get props => [
        producto,
        precio1,
        precio2,
        diferencia,
        porcentaje,
        cantidadPeriodo2,
      ];
}

class PriceComparisonResultEntity extends Equatable {
  final int productosComunes;
  final double inflacionPromedio;
  final int productosAumentaron;
  final List<PriceComparisonItemEntity> comparativa;

  const PriceComparisonResultEntity({
    required this.productosComunes,
    required this.inflacionPromedio,
    required this.productosAumentaron,
    required this.comparativa,
  });

  @override
  List<Object?> get props => [
        productosComunes,
        inflacionPromedio,
        productosAumentaron,
        comparativa,
      ];
}
