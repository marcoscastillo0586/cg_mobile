// Datos SINTÉTICOS con la forma de MovementDto/MovementsPageDto (@cg/shared).
// Prueban el parseo, no la API real.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/categories_admin/domain/category_item.dart';
import 'package:gastos_mobile/features/movements/data/movements_repository.dart';
import 'package:gastos_mobile/features/movements/domain/movement_item.dart';

Map<String, dynamic> _detail(int id, int amount, {String currency = 'ARS', String? role, String? plu, int? unit}) => {
      'id': id,
      'accountId': 3,
      'accountName': 'Efectivo',
      'accountActive': true,
      'currency': currency,
      'categoryId': 7,
      'categoryName': 'Comida',
      'categoryRole': role,
      'concept': 'Yerba',
      'observation': null,
      'amountCents': amount,
      'plu': plu,
      'unitPriceCents': unit,
      'imageUrl': null,
      'imageNote': null,
    };

void main() {
  test('egreso con varios renglones: signo contable, PLU y precio unitario', () {
    final m = MovementsRepository.parseMovement({
      'id': 99,
      'type': 2,
      'occurredAt': '2026-10-11 14:30:00',
      'generalConcept': 'Super',
      'accountNames': ['Efectivo'],
      'amountCents': -350050,
      'detailsCount': 2,
      'partialDetails': false,
      'details': [_detail(1, -150050, plu: '123', unit: 75025), _detail(2, -200000)],
      'fromAccountId': null,
      'toAccountId': null,
    });
    expect(m.type, MovementType.expense);
    expect(m.amountCents, -350050);
    expect(m.details.first.unitPriceCents, 75025);
    expect(m.details.first.plu, '123');
    expect(m.currency, Currency.ars);
    expect(Money.format(m.amountCents), r'-$ 3.500,50');
  });

  test('transferencia: importe positivo, origen y destino, categoría reservada', () {
    final m = MovementsRepository.parseMovement({
      'id': 5,
      'type': 3,
      'occurredAt': '2026-10-12 09:00:00',
      'generalConcept': 'Transferencia desde A hacia B',
      'accountNames': ['A', 'B'],
      'amountCents': 100000,
      'detailsCount': 2,
      'partialDetails': false,
      'details': [_detail(10, -100000, currency: 'USD', role: 'TRANSFER'), _detail(11, 100000, currency: 'USD', role: 'TRANSFER')],
      'fromAccountId': 1,
      'toAccountId': 2,
    });
    expect(m.type, MovementType.transfer);
    expect(m.currency, Currency.usd);
    expect(m.details.first.categoryRole, CategoryRole.transfer);
    expect(m.fromAccountId, 1);
  });

  test('tipo desconocido o importe con decimales: error de contrato', () {
    Map<String, dynamic> base() => {
          'id': 1,
          'type': 2,
          'occurredAt': '2026-10-11 14:30:00',
          'generalConcept': null,
          'accountNames': <String>[],
          'amountCents': -100,
          'detailsCount': 0,
          'partialDetails': false,
          'details': <Object>[],
          'fromAccountId': null,
          'toAccountId': null,
        };
    expect(() => MovementsRepository.parseMovement(base()..['type'] = 9), throwsA(isA<ServerException>()));
    expect(() => MovementsRepository.parseMovement(base()..['amountCents'] = -1.5), throwsA(isA<ServerException>()));
  });

  test('query: filtros de la API (accountIds en lista separada por coma, q recortada)', () {
    const q = MovementsQuery(from: '2026-10-01', to: '2026-10-31', accountIds: [1, 2], q: '  yerba ', offset: 50);
    expect(q.toQuery(), {
      'from': '2026-10-01',
      'to': '2026-10-31',
      'accountIds': '1,2',
      'q': 'yerba',
      'limit': 50,
      'offset': 50,
    });
  });
}
