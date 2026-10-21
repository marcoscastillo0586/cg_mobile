import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/analytics/data/models/product_price_model.dart';

void main() {
  group('ProductPrice Models & Entities Tests', () {
    test('Parsea correctamente JSON de catálogo de precios de productos', () {
      final json = {
        'concepto': 'LECHE LA SERENISIMA',
        'plu': '7791234567890',
        'total_compras': 12,
        'ultimo_precio': 1450.0,
        'primer_precio': 980.0,
        'precio_minimo': 950.0,
        'precio_maximo': 1450.0,
        'variacion_porcentaje': 47.9,
        'ultima_fecha': '2026-10-02',
        'primera_fecha': '2026-01-15',
        'ultimo_lugar': 'Coto',
      };

      final model = ProductPriceItemModel.fromJson(json);

      expect(model.concepto, 'LECHE LA SERENISIMA');
      expect(model.plu, '7791234567890');
      expect(model.totalCompras, 12);
      expect(model.ultimoPrecio, 1450.0);
      expect(model.haAumentado, true);
      expect(model.variacionPorcentaje, 47.9);
      expect(model.ultimoLugar, 'Coto');
    });

    test('Parsea correctamente JSON de historial cronológico de un producto', () {
      final json = {
        'concepto': 'YERBA PLAYADITO 1KG',
        'cantidad_compras': 3,
        'precio_actual': 4200.0,
        'precio_inicial': 3500.0,
        'precio_minimo': 3500.0,
        'precio_maximo': 4200.0,
        'aumento_porcentaje': 20.0,
        'historial': [
          {
            'id_movimiento_enc': 101,
            'fecha_hora': '2026-08-10 18:30',
            'fecha': '2026-08-10',
            'lugar_nombre': 'Carrefour',
            'categoria_nombre': 'Supermercado',
            'concepto': 'YERBA PLAYADITO 1KG',
            'precio_unitario': 3500.0,
            'cantidad': 1.0,
            'monto_total': 3500.0,
          },
          {
            'id_movimiento_enc': 142,
            'fecha_hora': '2026-09-12 11:15',
            'fecha': '2026-09-12',
            'lugar_nombre': 'Día',
            'categoria_nombre': 'Supermercado',
            'concepto': 'YERBA PLAYADITO 1KG',
            'precio_unitario': 3900.0,
            'cantidad': 2.0,
            'monto_total': 7800.0,
          },
          {
            'id_movimiento_enc': 205,
            'fecha_hora': '2026-10-01 19:40',
            'fecha': '2026-10-01',
            'lugar_nombre': 'Coto',
            'categoria_nombre': 'Supermercado',
            'concepto': 'YERBA PLAYADITO 1KG',
            'precio_unitario': 4200.0,
            'cantidad': 1.0,
            'monto_total': 4200.0,
          }
        ],
      };

      final model = ProductPriceHistoryModel.fromJson(json);

      expect(model.concepto, 'YERBA PLAYADITO 1KG');
      expect(model.cantidadCompras, 3);
      expect(model.precioActual, 4200.0);
      expect(model.precioMinimo, 3500.0);
      expect(model.precioMaximo, 4200.0);
      expect(model.historial.length, 3);
      expect(model.historial.first.lugarNombre, 'Carrefour');
      expect(model.historial.last.precioUnitario, 4200.0);
    });

    test('Parsea comparativa de precios e inflación entre 2 períodos', () {
      final json = {
        'periodo1': {'desde': '2026-08-01', 'hasta': '2026-08-31'},
        'periodo2': {'desde': '2026-09-01', 'hasta': '2026-09-30'},
        'totales': {
          'productos_comunes': 2,
          'inflacion_promedio': 12.5,
          'productos_aumentaron': 2,
        },
        'comparativa': [
          {
            'producto': 'ACEITE GIRASOL 1.5L',
            'precio1': 2000.0,
            'precio2': 2300.0,
            'diferencia': 300.0,
            'porcentaje': 15.0,
            'cantidad_periodo2': 2,
          },
          {
            'producto': 'AZUCAR LEDESMA 1KG',
            'precio1': 1000.0,
            'precio2': 1100.0,
            'diferencia': 100.0,
            'porcentaje': 10.0,
            'cantidad_periodo2': 1,
          }
        ],
      };

      final model = PriceComparisonResultModel.fromJson(json);

      expect(model.productosComunes, 2);
      expect(model.inflacionPromedio, 12.5);
      expect(model.productosAumentaron, 2);
      expect(model.comparativa.first.producto, 'ACEITE GIRASOL 1.5L');
      expect(model.comparativa.first.porcentaje, 15.0);
    });
  });
}
