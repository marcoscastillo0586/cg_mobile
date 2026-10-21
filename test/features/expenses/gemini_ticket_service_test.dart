import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/models/ticket_data.dart';

void main() {
  group('Gemini AI Ticket Data Parsing & Null-Safety Tests', () {
    test('deserializa respuesta JSON de Gemini 1.5 Flash correctamente', () {
      final geminiJson = {
        'comercio': 'COTO',
        'cuit': '30-54808315-6',
        'fecha': '02/10/2026',
        'hora': '17:32:15',
        'items': [
          {
            'descripcion': 'OBLEA RELLENA OPERAPAQ 220 GRM',
            'cantidad': 5,
            'precio_unitario': 2965.99,
            'precio_bruto': 2965.99,
            'descuento': 1038.10,
            'precio_final': 1927.89,
          },
          {
            'descripcion': 'ROLLO D/COCINA CLASICO SUSSEX',
            'cantidad': 1,
            'precio_unitario': 2957.99,
            'precio_bruto': 2957.99,
            'descuento': 1258.33,
            'precio_final': 1699.66,
          }
        ],
        'descuento_general': 0.0,
        'total': 103790.33,
      };

      final ticketData = TicketData.fromJson(geminiJson);

      expect(ticketData.fecha, '02/10/2026');
      expect(ticketData.total, 103790.33);
      expect(ticketData.items.length, 2);

      final item1 = ticketData.items.first;
      expect(item1.descripcion, 'OBLEA RELLENA OPERAPAQ 220 GRM');
      expect(item1.cantidad, 5.0);
      expect(item1.descuento, 1038.10);
      expect(item1.subtotal, 1927.89);
    });
  });
}
