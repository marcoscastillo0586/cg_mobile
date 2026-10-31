// Cuentas, categorías y límites sin conexión contra SQLite REAL (ffi). No prueba la red ni el
// servidor: el consumo de los límites se compara contra el servidor en el celular con
// tools/verify_sync.mjs.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/accounts_admin/data/local_accounts_repository.dart';
import 'package:gastos_mobile/features/categories_admin/data/local_categories_repository.dart';
import 'package:gastos_mobile/features/limits_admin/data/local_budgets_repository.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  setUp(() async => s = await seededDb());
  tearDown(() => s.db.close());

  Future<Map<String, Object?>> lastOp() async => (await s.db.query('outbox', orderBy: 'seq DESC', limit: 1)).single;
  Future<Map<String, dynamic>> lastData() async => jsonDecode((await lastOp())['data']! as String) as Map<String, dynamic>;
  Future<void> rule(Future<Object?> Function() f, String code) async {
    final ops = await s.count('outbox');
    await expectLater(f(), throwsA(isA<ValidationFailure>().having((e) => e.code, 'code', code)));
    expect(await s.count('outbox'), ops, reason: 'no debe encolarse nada');
  }

  group('cuentas', () {
    late LocalAccountsRepository repo;
    setUp(() => repo = LocalAccountsRepository(s.db));

    test('lista con saldo y renglones; alta con ícono de la API por la outbox', () async {
      final banco = (await repo.list()).firstWhere((a) => a.name == 'Banco');
      expect((banco.balanceCents, banco.movementsCount, banco.serverId), (100000, 1, 1));
      await repo.create(name: ' Billetera ', currency: Currency.usd, iconRef: 'alcancia');
      final op = await lastOp();
      expect((op['entity'], op['action'], op['client_id'] != null), ('account', 'create', true));
      expect(await lastData(), {'name': 'Billetera', 'currency': 'USD', 'iconRef': 'alcancia'});
      expect((await repo.list()).firstWhere((a) => a.name == 'Billetera').serverId, isNull);
    });

    test('nombres: largo, duplicado activo o inactivo (sin distinguir mayúsculas)', () async {
      await rule(() => repo.create(name: 'a', currency: Currency.ars), 'VALIDATION_ERROR'); // mínimo 2
      await rule(() => repo.create(name: 'x' * 16, currency: Currency.ars), 'VALIDATION_ERROR'); // máximo 15
      await rule(() => repo.create(name: 'BANCO', currency: Currency.ars), 'DUPLICATE_NAME');
      await expectLater(repo.create(name: 'cerrada', currency: Currency.ars),
          throwsA(isA<ValidationFailure>().having((e) => e.message, 'message', contains('activala'))));
      await rule(() => repo.update(s.accounts['Efectivo']!, name: 'banco'), 'DUPLICATE_NAME');
    });

    test('desactivar con saldo > 0 muestra el error; activar/desactivar NO manda el nombre', () async {
      await rule(() => repo.setActive(s.accounts['Banco']!, false), 'ACCOUNT_HAS_FUNDS');
      await repo.setActive(s.accounts['Cerrada']!, true);
      expect(await lastData(), {'active': true}); // defecto corregido: el nombre no viaja
      await repo.setActive(s.accounts['Cerrada']!, false);
      expect(await lastData(), {'active': false});
      final cerrada = (await s.db.query('accounts', where: 'local_id = ?', whereArgs: [s.accounts['Cerrada']])).single;
      expect((cerrada['name'], cerrada['active']), ('Cerrada', 0));
    });

    test('moneda bloqueada con movimientos (CURRENCY_LOCKED); sin movimientos se cambia', () async {
      await rule(() => repo.update(s.accounts['Banco']!, currency: Currency.usd), 'CURRENCY_LOCKED');
      await repo.update(s.accounts['Cerrada']!, currency: Currency.usd);
      expect(await lastData(), {'currency': 'USD'});
    });

    test('baja: con movimientos se desactiva (regla de saldo); alta no enviada se quita del celular', () async {
      await rule(() => repo.delete(s.accounts['Banco']!), 'ACCOUNT_HAS_FUNDS');
      await repo.create(name: 'Temporal', currency: Currency.ars);
      final id = (await repo.list()).firstWhere((a) => a.name == 'Temporal').id;
      expect(await repo.delete(id), isNull);
      expect(await s.count('outbox'), 0);
      expect(await s.count('accounts', "name = 'Temporal'"), 0);
    });
  });

  group('categorías', () {
    late LocalCategoriesRepository repo;
    setUp(() => repo = LocalCategoriesRepository(s.db));

    test('reservadas protegidas: no se renombran, desactivan ni borran', () async {
      for (final name in ['Transferencia', 'Ingreso', 'Ticket']) {
        final id = s.categories[name]!;
        await rule(() => repo.rename(id, 'Otra'), 'RESERVED_CATEGORY');
        await rule(() => repo.setActive(id, false), 'RESERVED_CATEGORY');
        await rule(() => repo.delete(id), 'RESERVED_CATEGORY');
      }
    });

    test('alta, renombrar y activar/desactivar (solo `active`, sin el nombre)', () async {
      await repo.create('Farmacia');
      expect(await lastData(), {'name': 'Farmacia'});
      await rule(() => repo.create('farmacia'), 'DUPLICATE_NAME');
      await repo.rename(s.categories['Super']!, 'Supermercado');
      expect(await lastData(), {'name': 'Supermercado'});
      await repo.setActive(s.categories['Comida']!, false);
      // Desactivar va como `delete` (mismo efecto en el servidor; ver setActive).
      expect((await lastOp())['action'], 'delete');
      expect(await lastData(), isEmpty);
      final c = (await s.db.query('categories', where: 'local_id = ?', whereArgs: [s.categories['Comida']])).single;
      expect((c['name'], c['active']), ('Comida', 0));
      await repo.setActive(s.categories['Comida']!, true);
      expect((await lastOp())['action'], 'update');
      expect(await lastData(), {'active': true});
    });
  });

  group('límites', () {
    late LocalBudgetsRepository repo;
    // "Hoy" en Buenos Aires: 2026-10-24.
    setUp(() => repo = LocalBudgetsRepository(s.db, now: () => DateTime.utc(2026, 10, 24, 15)));

    Future<int> gasto(String account, String category, int cents, String at, {int type = 2, int deleted = 0}) async {
      final h = await s.db.insert('movement_headers', {'client_id': 'h$at$cents$type', 'type': type, 'occurred_at': at, 'deleted': deleted, 'updated_at': 'x'});
      return s.db.insert('movement_details', {
        'header_local_id': h, 'account_local_id': s.accounts[account], 'category_local_id': s.categories[category],
        'amount_cents': type == 2 ? -cents : cents, 'updated_at': 'x',
      });
    }

    test('consumo con la regla del servidor: "hasta" completo, solo egresos y solo sus cuentas/categorías', () async {
      await gasto('Banco', 'Comida', 1000, '2026-10-01 00:00:00'); // primer instante: entra
      await gasto('Banco', 'Comida', 2000, '2026-10-31 23:59:59'); // último instante del "hasta": entra
      await gasto('Banco', 'Comida', 4000, '2026-11-01 00:00:00'); // fuera
      await gasto('Banco', 'Comida', 8000, '2026-09-30 23:59:59'); // fuera
      await gasto('Banco', 'Super', 16000, '2026-10-10 10:00:00'); // otra categoría
      await gasto('Efectivo', 'Comida', 32000, '2026-10-10 10:00:00'); // otra cuenta
      await gasto('Banco', 'Comida', 64000, '2026-10-10 10:00:00', type: 1); // ingreso
      await gasto('Banco', 'Comida', 128000, '2026-10-10 10:00:00', deleted: 1); // borrado
      await repo.create(startDate: '2026-10-01', endDate: '2026-10-31', limitCents: 4000,
          categoryIds: [s.categories['Comida']!], accountIds: [s.accounts['Banco']!]);
      final b = (await repo.list()).single;
      expect(b.consumedCents, 3000);
      expect(b.percentHundredths, 7500); // 75,00 % → "cerca"
      expect(b.remainingCents, 1000);
      expect(b.dueForRenewal, isFalse);
    });

    test('porcentaje truncado a centésimos (no redondeado) y vencimiento con la fecha de Buenos Aires', () async {
      await gasto('Banco', 'Comida', 2, '2026-10-05 10:00:00');
      await repo.create(startDate: '2026-10-01', endDate: '2026-10-24', limitCents: 3,
          categoryIds: [s.categories['Comida']!], accountIds: [s.accounts['Banco']!]);
      final b = (await repo.list()).single;
      expect(b.percentHundredths, 6666); // 66,666… → 66,66
      expect(b.dueForRenewal, isTrue); // hoy (24) >= hasta (24)
      expect(LocalBudgetsRepository.truncatedPercentHundredths(1, 0), isNull);
    });

    test('alta: payload con refs; categorías reservadas, más de 5 o período inválido se rechazan', () async {
      await repo.create(startDate: '2026-10-01', endDate: '2026-10-31', limitCents: 150050,
          categoryIds: [s.categories['Comida']!, s.categories['Super']!], accountIds: [s.accounts['Banco']!]);
      expect(await lastData(), {
        'startDate': '2026-10-01', 'endDate': '2026-10-31', 'limit': '1500.50',
        'categoryRefs': [{'serverId': 5}, {'serverId': 6}], 'accountRefs': [{'serverId': 1}],
      });
      Future<String> crear({List<int>? cats, String start = '2026-10-01', String end = '2026-10-31'}) => repo.create(
          startDate: start, endDate: end, limitCents: 1, categoryIds: cats ?? [s.categories['Comida']!], accountIds: [s.accounts['Banco']!]);
      await rule(() => crear(cats: [s.categories['Transferencia']!]), 'RESERVED_CATEGORY');
      await rule(() => crear(end: '2026-09-30'), 'INVALID_PERIOD');
      for (var i = 0; i < 4; i++) {
        await s.db.insert('categories', {'server_id': 70 + i, 'name': 'Extra $i', 'updated_at': 'x'});
      }
      final seis = (await s.db.query('categories', columns: ['local_id'], where: 'role IS NULL')).map((r) => r['local_id']! as int).toList();
      expect(seis.length, greaterThanOrEqualTo(6));
      await rule(() => crear(cats: seis), 'VALIDATION_ERROR');
    });

    test('renovar: desde +1 mes y hasta = último día del mes siguiente (semántica MySQL)', () async {
      expect(LocalBudgetsRepository.addMonths('2026-01-31', 1), '2026-02-28');
      expect(LocalBudgetsRepository.addMonths('2028-01-31', 1), '2028-02-29'); // bisiesto
      expect(LocalBudgetsRepository.addMonths('2026-12-15', 1), '2027-01-15');
      expect(LocalBudgetsRepository.lastDayOfMonth('2026-02-10'), '2026-02-28');
      await repo.create(startDate: '2026-01-31', endDate: '2026-01-31', limitCents: 1,
          categoryIds: [s.categories['Comida']!], accountIds: [s.accounts['Banco']!]);
      final b = (await repo.list()).single;
      await repo.renew(b.id);
      final r = (await repo.list()).single;
      expect((r.startDate, r.endDate), ('2026-02-28', '2026-02-28'));
      expect(await lastData(), {'renew': true});
    });
  });
}
