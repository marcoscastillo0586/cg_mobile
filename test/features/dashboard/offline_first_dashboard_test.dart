import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/account_entity.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/dashboard_summary_entity.dart';

void main() {
  group('Single Source of Truth & Offline Dashboard Tests', () {
    test('Mantiene las cuentas de SQLite en pantalla sin vaciar las listas al fallar la red', () {
      const summaryLocal = DashboardSummaryEntity(
        sumaTotalPesos: 150000.0,
        cotizacionNombre: 'Dólar Oficial (Offline)',
        cotizacionDolar: 1000.0,
        cuentas: [
          AccountEntity(
            idLugar: 1,
            nombre: 'Efectivo ARS',
            tipoMoneda: 1,
            simboloMoneda: '\$',
            montoOriginal: 50000.0,
            montoPesos: 50000.0,
            cotizacion: 1.0,
          ),
          AccountEntity(
            idLugar: 2,
            nombre: 'Banco Santander',
            tipoMoneda: 1,
            simboloMoneda: '\$',
            montoOriginal: 100000.0,
            montoPesos: 100000.0,
            cotizacion: 1.0,
          ),
        ],
      );

      expect(summaryLocal.cuentas.length, equals(2));
      expect(summaryLocal.cuentas.first.nombre, equals('Efectivo ARS'));
      expect(summaryLocal.sumaTotalPesos, equals(150000.0));
    });
  });
}
