import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/limits_admin/domain/entities/expense_limit_admin_entity.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/providers/limits_admin_state.dart';

void main() {
  group('LimitsAdminState & Entity Tests', () {
    final limitActivo = ExpenseLimitAdminEntity(
      idLimiteGasto: 1,
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 31),
      montoLimite: 100000.0,
      montoConsumido: 40000.0,
      resto: 60000.0,
      porcentaje: 40.0,
      vencido: false,
      categoria: '3,8',
      categoriasNombres: 'Comida, Bebidas',
      lugar: '1,2',
      lugaresNombres: 'Efectivo, Galicia',
    );

    final limitExcedido = ExpenseLimitAdminEntity(
      idLimiteGasto: 2,
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 31),
      montoLimite: 50000.0,
      montoConsumido: 75000.0,
      resto: -25000.0,
      porcentaje: 150.0,
      vencido: false,
      categoria: '11',
      categoriasNombres: 'Esparcimiento',
      lugar: '11',
      lugaresNombres: 'Mercado Pago',
    );

    final limitVencido = ExpenseLimitAdminEntity(
      idLimiteGasto: 3,
      desde: DateTime(2026, 9, 1),
      hasta: DateTime(2026, 9, 30),
      montoLimite: 80000.0,
      montoConsumido: 50000.0,
      resto: 30000.0,
      porcentaje: 62.5,
      vencido: true,
      categoria: '7',
      categoriasNombres: 'Farmacia',
      lugar: '1',
      lugaresNombres: 'Efectivo',
    );

    test('calcula correctamente propiedades de ExpenseLimitAdminEntity', () {
      expect(limitActivo.excedido, isFalse);
      expect(limitExcedido.excedido, isTrue);
      expect(limitActivo.factorUso, 0.4);
      expect(limitExcedido.factorUso, 1.0); // Clamped to 1.0
      expect(limitActivo.categoriasIds, [3, 8]);
      expect(limitActivo.lugaresIds, [1, 2]);
    });

    test('calcula totales globales de presupuesto activo correctamente', () {
      final state = LimitsAdminState.initial().copyWith(
        status: LimitsAdminStatus.loaded,
        limits: [limitActivo, limitExcedido, limitVencido],
      );

      // Solo toma los límites activos (no vencidos): 100k + 50k = 150k
      expect(state.totalPresupuestado, 150000.0);
      // Consumido activo: 40k + 75k = 115k
      expect(state.totalConsumido, 115000.0);
      // Resto activo: 150k - 115k = 35k
      expect(state.totalResto, 35000.0);
      expect(state.activosCount, 2);
      expect(state.vencidosCount, 1);
      expect(state.excedidosCount, 1);
    });

    test('filtra limites por estado adecuadamente', () {
      var state = LimitsAdminState.initial().copyWith(
        limits: [limitActivo, limitExcedido, limitVencido],
      );

      // Todos
      expect(state.limitsFiltrados.length, 3);

      // Activos
      state = state.copyWith(filtroEstado: 'activos');
      expect(state.limitsFiltrados.length, 2);

      // Excedidos
      state = state.copyWith(filtroEstado: 'excedidos');
      expect(state.limitsFiltrados.length, 1);
      expect(state.limitsFiltrados.first.idLimiteGasto, 2);

      // Vencidos
      state = state.copyWith(filtroEstado: 'vencidos');
      expect(state.limitsFiltrados.length, 1);
      expect(state.limitsFiltrados.first.idLimiteGasto, 3);
    });
  });
}
