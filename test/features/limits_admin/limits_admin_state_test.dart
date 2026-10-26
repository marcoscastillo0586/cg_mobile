// Datos SINTÉTICOS: prueban las reglas de la pantalla de límites y de la campana sobre el
// modelo local (el cálculo del consumo se prueba en local_budgets_repository_test).
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/novedad_entity.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/limits_admin/domain/budget.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/providers/limits_admin_state.dart';

/// [percent] en centésimos (7550 = 75,50 %).
Budget _b({int id = 1, int limit = 100000, int consumed = 50000, int? percent = 5000, bool due = false, List<String> cats = const ['Comida'], Currency? currency = Currency.ars}) =>
    Budget(
      id: id,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      limitCents: limit,
      consumedCents: consumed,
      percentHundredths: percent,
      dueForRenewal: due,
      categories: [for (var i = 0; i < cats.length; i++) BudgetRef(i + 10, cats[i])],
      accounts: const [BudgetRef(3, 'Efectivo')],
      currency: currency,
    );

void main() {
  test('resto y excedente en centavos; porcentaje para mostrar desde centésimos', () {
    final b = _b(limit: 123456, consumed: 130000, percent: 10530);
    expect(b.remainingCents, -6544);
    expect(b.exceeded, isTrue);
    expect(b.percent, 105.3);
  });

  test('título: categorías ordenadas por nombre', () {
    expect(_b(cats: ['Super', 'Almacén']).title, 'Almacén, Super');
  });

  test('totales: solo presupuestos vigentes (no vencidos), sumando centavos de cada moneda', () {
    final s = LimitsAdminState.initial().copyWith(limits: [
      _b(id: 1, limit: 100000, consumed: 25000),
      _b(id: 2, limit: 50000, consumed: 60000, percent: 12000),
      _b(id: 3, limit: 999999, consumed: 1, due: true),
      _b(id: 4, limit: 20000, consumed: 5000, currency: Currency.usd),
      _b(id: 5, limit: 7000, consumed: 7000, currency: null), // mezcla monedas: no suma en ninguna
    ]);
    expect(s.totalPresupuestadoCents(Currency.ars), 150000);
    expect(s.totalConsumidoCents(Currency.ars), 85000);
    expect(s.totalRestoCents(Currency.ars), 65000);
    expect((s.totalPresupuestadoCents(Currency.usd), s.totalConsumidoCents(Currency.usd)), (20000, 5000));
    expect(s.monedasVigentes, {Currency.ars, Currency.usd});
    expect(s.activosCount, 4);
    expect(s.vencidosCount, 1);
    expect(s.excedidosCount, 1);
  });

  test('filtros y orden por nombre', () {
    final s = LimitsAdminState.initial().copyWith(limits: [
      _b(id: 1, cats: ['Zapatos']),
      _b(id: 2, cats: ['Agua'], due: true),
      _b(id: 3, cats: ['Luz'], consumed: 200000, percent: 20000),
    ]);
    expect(s.limitsFiltrados.map((b) => b.id), [2, 3, 1]);
    expect(s.copyWith(filtroEstado: 'activos').limitsFiltrados.map((b) => b.id), [3, 1]);
    expect(s.copyWith(filtroEstado: 'vencidos').limitsFiltrados.map((b) => b.id), [2]);
    expect(s.copyWith(filtroEstado: 'excedidos').limitsFiltrados.map((b) => b.id), [3]);
  });

  test('campana: umbrales exactos (centésimos enteros, sin double)', () {
    expect(tipoNovedad(_b(percent: 7499)), isNull);
    expect(tipoNovedad(_b(percent: 7500)), NovedadTipo.cerca);
    expect(tipoNovedad(_b(percent: 9999)), NovedadTipo.cerca);
    expect(tipoNovedad(_b(percent: 10000)), NovedadTipo.alcanzado);
    expect(tipoNovedad(_b(percent: null)), isNull);
    expect(tipoNovedad(_b(percent: 1000, due: true)), NovedadTipo.vencido);
  });
}
