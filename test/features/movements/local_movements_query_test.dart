// Historial sin conexión: GET /movements calculado sobre la base del celular (SQLite REAL, ffi), con la misma
// forma y reglas que la API.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/movements/data/local_movements_query.dart';
import 'package:gastos_mobile/features/movements/data/movements_repository.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late LocalMovementsQuery query;
  late int unsentId;

  Future<int> header(int? serverId, int type, String at, String concept, {int deleted = 0}) => s.db.insert('movement_headers', {
        'server_id': serverId,
        'client_id': serverId == null ? 'local-$at' : null,
        'type': type,
        'occurred_at': at,
        'general_concept': concept,
        'deleted': deleted,
        'created_by_user_id': 7,
        'created_by_name': 'Ana',
        'updated_at': 'x',
      });
  Future<void> detail(int header, String account, String? category, int cents, String concept, {int? serverId}) => s.db.insert('movement_details', {
        'server_id': serverId,
        'header_local_id': header,
        'account_local_id': s.accounts[account],
        'category_local_id': category == null ? null : s.categories[category],
        'amount_cents': cents,
        'concept': concept,
        'updated_at': 'x',
      });

  setUp(() async {
    s = await seededDb(); // ingresos iniciales: Banco 101, Efectivo 102, Dolares 103 (2026-01-01)
    query = LocalMovementsQuery(s.db);
    final super_ = await header(900, 2, '2026-10-10 10:00:00', 'Supermercado');
    await detail(super_, 'Banco', 'Comida', -150000, 'Pan', serverId: 9001);
    await detail(super_, 'Efectivo', 'Super', -2550, 'Leche 50%', serverId: 9002);
    final transfer = await header(901, 3, '2026-10-11 09:00:00', 'Transferencia');
    await detail(transfer, 'Banco', 'Transferencia', -10000, 'Transferencia', serverId: 9011);
    await detail(transfer, 'Efectivo', 'Transferencia', 10000, 'Transferencia', serverId: 9012);
    unsentId = await header(null, 2, '2026-10-11 12:00:00', 'Kiosco');
    await detail(unsentId, 'Banco', 'Comida', -1234, 'Alfajor');
    final gone = await header(902, 2, '2026-10-12 10:00:00', 'Borrado', deleted: 1);
    await detail(gone, 'Banco', 'Comida', -1, 'x', serverId: 9021);
    final closed = await header(903, 1, '2026-10-12 10:00:00', 'Cuenta cerrada');
    await detail(closed, 'Cerrada', 'Ingreso', 1, 'x', serverId: 9031);
  });
  tearDown(() => s.db.close());

  List<Object?> ids(Map<String, dynamic> page) => [for (final i in page['items'] as List) (i as Map)['id']];
  Map<String, dynamic> item(Map<String, dynamic> page, int id) => (page['items'] as List).cast<Map<String, dynamic>>().firstWhere((i) => i['id'] == id);

  test('sin filtros: más nuevo primero (lo no enviado con id local negativo), sin borrados ni cuentas inactivas', () async {
    final page = await query.list(const MovementsQuery());
    expect(ids(page), [-unsentId, 901, 900, 103, 102, 101]);
    expect(page, containsPair('total', 6));
    expect(page['hasMore'], false);
    // −1.234 + 10.000 (transferencia: un solo lado) − 152.550 + 100.000 + 5.000 + 10.000
    expect(page['filteredTotalCents'], 28784);
  });

  test('forma de cada movimiento: importe, cuentas, autor y transferencia como par', () async {
    final page = await query.list(const MovementsQuery());
    final expense = item(page, 900);
    expect(expense, containsPair('amountCents', -152550));
    expect(expense['accountNames'], unorderedEquals(['Banco', 'Efectivo']));
    expect(expense, containsPair('detailsCount', 2));
    expect(expense, containsPair('partialDetails', false));
    expect(expense, containsPair('createdByName', 'Ana'));
    expect((expense['details'] as List).first, containsPair('categoryName', 'Super')); // categoría descendente
    final transfer = item(page, 901);
    expect(transfer, containsPair('amountCents', 10000));
    expect(transfer['accountNames'], ['Banco', 'Efectivo']);
    expect(transfer, containsPair('fromAccountId', 1));
    expect(transfer, containsPair('toAccountId', 2));
    final unsent = item(page, -unsentId);
    expect((unsent['details'] as List).single, containsPair('id', isNegative));
    expect(item(page, 101)['accountNames'], ['Banco']);
  });

  test('tamaño de página por defecto: 60 sin fechas, 100 con rango; paginado con hasMore', () async {
    expect((await query.list(const MovementsQuery(limit: 0)))['limit'], 60);
    expect((await query.list(const MovementsQuery(limit: 0, from: '2026-01-01')))['limit'], 100);
    expect((await query.list(const MovementsQuery(limit: 0, to: '2026-12-31')))['limit'], 100);
    final first = await query.list(const MovementsQuery(limit: 2));
    expect([ids(first), first['hasMore']], [[-unsentId, 901], true]);
    final last = await query.list(const MovementsQuery(limit: 2, offset: 4));
    expect([ids(last), last['hasMore']], [[102, 101], false]);
  });

  test('rango de fechas: incluye el día hasta completo', () async {
    expect(ids(await query.list(const MovementsQuery(from: '2026-10-11'))), [-unsentId, 901]);
    expect(ids(await query.list(const MovementsQuery(from: '2026-10-10', to: '2026-10-10'))), [900]);
  });

  test('filtro por categoría o cuenta: sólo los renglones que cumplen, marcados como parciales', () async {
    final bySuper = await query.list(const MovementsQuery(categoryIds: [6]));
    expect(ids(bySuper), [900]);
    expect(item(bySuper, 900), containsPair('amountCents', -2550));
    expect(item(bySuper, 900), containsPair('partialDetails', true));
    expect((item(bySuper, 900)['details'] as List).single, containsPair('concept', 'Leche 50%'));

    final byEfectivo = await query.list(const MovementsQuery(accountIds: [2]));
    expect(ids(byEfectivo), [901, 900, 102]);
    expect(item(byEfectivo, 901), containsPair('partialDetails', true));
    expect(item(byEfectivo, 102), containsPair('partialDetails', false));
  });

  test('búsqueda por texto: por el concepto general muestra todo; por un renglón, sólo ese', () async {
    final general = await query.list(const MovementsQuery(q: ' super '));
    expect(ids(general), [900]);
    expect(item(general, 900), containsPair('partialDetails', false));
    final line = await query.list(const MovementsQuery(q: 'PAN'));
    expect(ids(line), [900]);
    expect(item(line, 900), containsPair('partialDetails', true));
    expect((item(line, 900)['details'] as List).single, containsPair('concept', 'Pan'));
    // % y _ se buscan literalmente.
    expect(ids(await query.list(const MovementsQuery(q: '50%'))), [900]);
    expect(ids(await query.list(const MovementsQuery(q: 'a_f'))), isEmpty);
  });

  test('búsqueda por monto: pesos enteros (cualquier centavo) o importe exacto con decimales', () async {
    final pesos = await query.list(const MovementsQuery(q: '1500'));
    expect(ids(pesos), [900]);
    expect((item(pesos, 900)['details'] as List).single, containsPair('concept', 'Pan'));
    expect(ids(await query.list(const MovementsQuery(q: '\$ 25,50'))), [900]);
    expect(ids(await query.list(const MovementsQuery(q: '12.34'))), [-unsentId]);
    expect(ids(await query.list(const MovementsQuery(q: '12.35'))), isEmpty);
  });
}
