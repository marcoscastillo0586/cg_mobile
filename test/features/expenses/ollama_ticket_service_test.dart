import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/models/ticket_data.dart';

void main() {
  group('TicketData & ComercioData Null-Safety Deserialization Tests', () {
    test('deserializa correctamente un JSON completo de comercio e items con CUIT', () {
      final json = {
        'comercio': {
          'nombre_comercial': 'COTO',
          'razon_social': 'COTO C.I.C.S.A.',
          'cuit': '30-54808315-6',
          'cuit_valido': true,
          'domicilio': 'AV. HIPOLITO YRIGOYEN 1826',
          'fecha': '02/10/2026',
        },
        'fecha': '2026-10-02',
        'moneda': 'ARS',
        'items': [
          {
            'descripcion': 'OBLEA RELLENA OPERAPAQ',
            'cantidad': 5,
            'precio_unitario': 2965.99,
            'descuento': 1038.10,
            'subtotal': 1927.89,
          },
        ],
        'descuento_general': 0.0,
        'total': 103790.33,
      };

      final ticket = TicketData.fromJson(json);

      expect(ticket.comercio?.nombreComercial, 'COTO');
      expect(ticket.comercio?.cuit, '30-54808315-6');
      expect(ticket.comercio?.cuitValido, isTrue);
      expect(ticket.total, 103790.33);
      expect(ticket.items.length, 1);

      final item = ticket.items.first;
      expect(item.descripcion, 'OBLEA RELLENA OPERAPAQ');
      expect(item.cantidad, 5.0);
      expect(item.precioUnitario, 2965.99);
      expect(item.descuento, 1038.10);
      expect(item.subtotal, 1927.89);
    });

    test('tolerancia a nulos y alucinaciones (ticket cortado sin total ni campos opcionales)', () {
      final json = {
        'comercio': null,
        'fecha': null,
        'moneda': null,
        'items': [
          {
            'descripcion': 'Producto Incompleto',
            'cantidad': null,
            'precio_unitario': null,
            'descuento': null,
            'subtotal': null,
          }
        ],
        'descuento_general': null,
        'total': null,
      };

      final ticket = TicketData.fromJson(json);

      expect(ticket.comercio, isNull);
      expect(ticket.fecha, isNull);
      expect(ticket.moneda, isNull);
      expect(ticket.total, isNull);
      expect(ticket.descuentoGeneral, 0.0);
      expect(ticket.items.length, 1);

      final item = ticket.items.first;
      expect(item.descripcion, 'Producto Incompleto');
      expect(item.cantidad, 1.0);
      expect(item.precioUnitario, isNull);
      expect(item.descuento, 0.0);
      expect(item.subtotal, 0.0);
    });

    test('calcula subtotal como fallback si viene nulo pero existen cantidad y precio unitario', () {
      final json = {
        'descripcion': 'Aceite de Girasol 900ml',
        'cantidad': 3,
        'precio_unitario': 1500,
        'descuento': 100,
        'subtotal': null,
      };

      final item = TicketItemData.fromJson(json);

      expect(item.descripcion, 'Aceite de Girasol 900ml');
      expect(item.cantidad, 3.0);
      expect(item.precioUnitario, 1500.0);
      expect(item.descuento, 100.0);
      expect(item.subtotal, 4400.0); // (3 * 1500) - 100 = 4400
    });
  });
}
