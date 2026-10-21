import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/movements/data/models/movement_detail_model.dart';

void main() {

  group('MovementDetailModel & Entity Tests', () {
    test('Parsea correctamente JSON de un egreso con desglose de ítems', () {
      final json = {
        'id_movimiento_enc': 105,
        'tipo_movimiento': 2,
        'concepto_general': 'Supermercado Día',
        'fecha': '2026-10-03 16:45:00',
        'monto_total': 18500.50,
        'id_lugar_origen': 0,
        'id_lugar_destino': 0,
        'detalles': [
          {
            'id_movimiento_det': 201,
            'id_lugar': 2,
            'lugar_nombre': 'Mercado Pago',
            'id_categoria': 3,
            'categoria_nombre': 'Supermercado',
            'concepto': 'Leche descremada',
            'monto': 3500.50,
            'signo': -1,
            'cantidad': 2.0,
            'codigo': '7791234567890',
          },
          {
            'id_movimiento_det': 202,
            'id_lugar': 2,
            'lugar_nombre': 'Mercado Pago',
            'id_categoria': 3,
            'categoria_nombre': 'Supermercado',
            'concepto': 'Carne picada especial',
            'monto': 15000.00,
            'signo': -1,
            'cantidad': 1.0,
            'codigo': '',
          }
        ],
      };

      final model = MovementDetailModel.fromJson(json);

      expect(model.idMovimientoEnc, 105);
      expect(model.isExpense, true);
      expect(model.isIncome, false);
      expect(model.isTransfer, false);
      expect(model.montoTotal, 18500.50);
      expect(model.detalles.length, 2);
      expect(model.detalles.first.concepto, 'Leche descremada');
      expect(model.detalles.first.monto, 3500.50);
      expect(model.detalles.last.concepto, 'Carne picada especial');
    });

    test('Parsea correctamente JSON de una transferencia entre cuentas', () {
      final json = {
        'id_movimiento_enc': 304,
        'tipo_movimiento': 3,
        'concepto_general': 'Pase a Banco Galicia',
        'fecha': '2026-10-02 11:20:00',
        'monto_total': 50000.0,
        'id_lugar_origen': 1,
        'id_lugar_destino': 4,
        'detalles': [
          {
            'id_movimiento_det': 501,
            'id_lugar': 4,
            'lugar_nombre': 'Banco Galicia',
            'id_categoria': 1,
            'categoria_nombre': 'Transferencia',
            'concepto': 'Pase a Banco Galicia',
            'monto': 50000.0,
            'signo': 1,
            'cantidad': 1.0,
            'codigo': '',
          },
          {
            'id_movimiento_det': 502,
            'id_lugar': 1,
            'lugar_nombre': 'Efectivo',
            'id_categoria': 1,
            'categoria_nombre': 'Transferencia',
            'concepto': 'Pase a Banco Galicia',
            'monto': 50000.0,
            'signo': -1,
            'cantidad': 1.0,
            'codigo': '',
          }
        ],
      };

      final model = MovementDetailModel.fromJson(json);

      expect(model.idMovimientoEnc, 304);
      expect(model.isTransfer, true);
      expect(model.idLugarOrigen, 1);
      expect(model.idLugarDestino, 4);
      expect(model.detalles.length, 2);
    });
  });
}
