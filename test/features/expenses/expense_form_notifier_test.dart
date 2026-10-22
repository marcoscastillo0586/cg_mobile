// Formulario de egreso contra SQLite REAL (ffi). No prueba la pantalla ni el celular.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/ticket_parse_result.dart';
import 'package:gastos_mobile/features/expenses/presentation/providers/expense_form_notifier.dart';
import 'package:gastos_mobile/features/expenses/presentation/providers/expense_form_state.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late ProviderContainer container;
  late ExpenseFormNotifier notifier;

  setUp(() async {
    s = await seededDb();
    container = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
    container.listen(expenseFormNotifierProvider, (_, __) {}); // evita el autoDispose
    notifier = container.read(expenseFormNotifierProvider.notifier);
    await notifier.inicializar();
  });

  tearDown(() async {
    container.dispose();
    await s.db.close();
  });

  String first() => notifier.state.renglones.first.id;

  test('carga cuentas activas y categorías de egreso de la base local; sin cuenta elegida', () {
    expect(notifier.state.status, ExpenseFormStatus.ready);
    expect(notifier.state.cuentas.map((c) => c.name), ['Banco', 'Dolares', 'Efectivo']); // sin la inactiva
    expect(notifier.state.categorias.map((c) => c.name), ['Comida', 'Super', 'Ticket']); // sin reservadas
    expect(notifier.state.selectedCuentaId, isNull);
    expect(notifier.state.renglones, hasLength(1));
  });

  test('total en centavos enteros y aviso de fondos antes de guardar', () {
    notifier.setCuenta(s.accounts['Efectivo']!);
    notifier.actualizarMonto(first(), 4000);
    notifier.agregarRenglon();
    notifier.actualizarMonto(notifier.state.renglones[1].id, 1001);
    expect(notifier.state.totalCents, 5001);
    expect(notifier.state.fondosInsuficientes, isTrue); // saldo 5000
    notifier.actualizarMonto(notifier.state.renglones[1].id, 1000);
    expect(notifier.state.fondosInsuficientes, isFalse);
  });

  test('guardar escribe en SQLite y la outbox y descuenta el saldo local', () async {
    notifier.setCuenta(s.accounts['Banco']!);
    notifier.setConceptoGeneral('Compras');
    notifier.actualizarMonto(first(), 4500);
    notifier.actualizarCategoria(first(), s.categories['Super']!);
    expect(await notifier.guardarEgreso(), isTrue);
    expect(notifier.state.status, ExpenseFormStatus.success);
    expect(await s.count('outbox', "status = 'pending'"), 1);
    expect(await s.balance('Banco'), 100000 - 4500);
    // Renglón sin concepto: toma el concepto general.
    expect(await s.count('movement_details', "concept = 'Compras' AND amount_cents = -4500"), 1);
  });

  test('sin fondos no se guarda nada y el error queda para mostrar', () async {
    notifier.setCuenta(s.accounts['Efectivo']!);
    notifier.setConceptoGeneral('x');
    notifier.actualizarMonto(first(), 5001);
    expect(await notifier.guardarEgreso(), isFalse);
    expect((notifier.state.error! as Failure).code, 'INSUFFICIENT_FUNDS');
    expect(notifier.state.status, ExpenseFormStatus.ready);
    expect(await s.count('outbox'), 0);
  });

  test('sin cuenta: error de validación, no se escribe', () async {
    notifier.actualizarMonto(first(), 100);
    expect(await notifier.guardarEgreso(), isFalse);
    expect((notifier.state.error! as Failure).code, 'VALIDATION_ERROR');
    expect(await s.count('movement_headers', 'server_id IS NULL'), 0);
  });

  test('ticket: precios a centavos y categoría DEFAULT_TICKET', () {
    notifier.aplicarResultadoTicket(const TicketParseResult(readerName: 'test', rawTexts: [], imagePaths: [], items: [
      ParsedTicketItem(nombre: 'Leche', precio: 1234.5),
      ParsedTicketItem(nombre: 'Pan', precio: 0.1),
    ]));
    expect(notifier.state.renglones.map((r) => (r.concepto, r.montoCents, r.categoriaId)), [
      ('Leche', 123450, s.categories['Ticket']),
      ('Pan', 10, s.categories['Ticket']),
    ]);
  });

  test('sugerencia sin conexión: la última categoría usada con ese concepto', () async {
    final w = await s.writer;
    await w.createExpense(ExpenseDraft(accountLocalId: s.accounts['Banco']!, date: DateTime(2026, 1, 2), generalConcept: 'x',
        lines: [ExpenseLine(concept: 'Verduras', categoryLocalId: s.categories['Super']!, amountCents: 100)]));
    notifier.actualizarConcepto(first(), 'verduras');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(notifier.state.renglones.first.categoriaId, s.categories['Super']);
  });
}
