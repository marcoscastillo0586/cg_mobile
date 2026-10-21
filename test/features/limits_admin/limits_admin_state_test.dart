// Datos SINTÉTICOS: prueban el parseo del BudgetDto y las reglas de la pantalla y de la
// campana. No prueban la API real (eso lo hace el test en vivo).
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/novedad_entity.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/limits_admin/data/budgets_repository.dart';
import 'package:gastos_mobile/features/limits_admin/domain/budget.dart';
import 'package:gastos_mobile/features/limits_admin/presentation/providers/limits_admin_state.dart';

Map<String, dynamic> _json({
  int id = 1,
  int limit = 100000,
  int consumed = 50000,
  num? percent = 50,
  bool due = false,
  List<String> cats = const ['Comida'],
}) =>
    {
      'id': id,
      'startDate': '2026-10-01',
      'endDate': '2026-10-31',
      'limitCents': limit,
      'consumedCents': consumed,
      'remainingCents': limit - consumed,
      'percent': percent,
      'dueForRenewal': due,
      'categories': [for (var i = 0; i < cats.length; i++) {'id': i + 10, 'name': cats[i]}],
      'accounts': [{'id': 3, 'name': 'Efectivo'}],
    };

Budget _b({int id = 1, int limit = 100000, int consumed = 50000, num? percent = 50, bool due = false, List<String> cats = const ['Comida']}) =>
    BudgetsRepository.parse(_json(id: id, limit: limit, consumed: consumed, percent: percent, due: due, cats: cats));

void main() {
  test('parsea BudgetDto en centavos y usa los valores del servidor tal cual', () {
    final b = _b(limit: 123456, consumed: 130000, percent: 105.3);
    expect(b.limitCents, 123456);
    expect(b.consumedCents, 130000);
    expect(b.remainingCents, -6544);
    expect(b.percent, 105.3);
    expect(b.exceeded, isTrue);
    expect(b.accounts.single.name, 'Efectivo');
  });

  test('título: categorías ordenadas por nombre', () {
    expect(_b(cats: ['Super', 'Almacén']).title, 'Almacén, Super');
  });

  test('un importe con decimales es error de contrato, no se redondea', () {
    final j = _json()..['consumedCents'] = 10.5;
    expect(() => BudgetsRepository.parse(j), throwsA(isA<ServerException>()));
  });

  test('totales: solo presupuestos vigentes (no vencidos), sumando centavos', () {
    final s = LimitsAdminState.initial().copyWith(limits: [
      _b(id: 1, limit: 100000, consumed: 25000),
      _b(id: 2, limit: 50000, consumed: 60000, percent: 120),
      _b(id: 3, limit: 999999, consumed: 1, due: true),
    ]);
    expect(s.totalPresupuestadoCents, 150000);
    expect(s.totalConsumidoCents, 85000);
    expect(s.totalRestoCents, 65000);
    expect(s.activosCount, 2);
    expect(s.vencidosCount, 1);
    expect(s.excedidosCount, 1);
  });

  test('filtros y orden por nombre', () {
    final s = LimitsAdminState.initial().copyWith(limits: [
      _b(id: 1, cats: ['Zapatos']),
      _b(id: 2, cats: ['Agua'], due: true),
      _b(id: 3, cats: ['Luz'], consumed: 200000, percent: 200),
    ]);
    expect(s.limitsFiltrados.map((b) => b.id), [2, 3, 1]);
    expect(s.copyWith(filtroEstado: 'activos').limitsFiltrados.map((b) => b.id), [3, 1]);
    expect(s.copyWith(filtroEstado: 'vencidos').limitsFiltrados.map((b) => b.id), [2]);
    expect(s.copyWith(filtroEstado: 'excedidos').limitsFiltrados.map((b) => b.id), [3]);
  });

  test('campana: umbrales exactos con el percent del servidor', () {
    expect(tipoNovedad(_b(percent: 74.99)), isNull);
    expect(tipoNovedad(_b(percent: 75)), NovedadTipo.cerca);
    expect(tipoNovedad(_b(percent: 99.99)), NovedadTipo.cerca);
    expect(tipoNovedad(_b(percent: 100)), NovedadTipo.alcanzado);
    expect(tipoNovedad(_b(percent: null)), isNull);
    expect(tipoNovedad(_b(percent: 10, due: true)), NovedadTipo.vencido);
  });
}
