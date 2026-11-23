// Corregir un comprobante rechazado: el formulario de egreso o de transferencia se precarga con lo enviado
// (SQLite REAL, ffi).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/sync/outbox_repository.dart';
import 'package:gastos_mobile/features/expenses/presentation/providers/expense_form_notifier.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:gastos_mobile/features/transfers/presentation/providers/transfer_form_notifier.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late ProviderContainer container;

  setUp(() async {
    s = await seededDb();
    container = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await s.db.close();
  });

  test('egreso: cuenta, fecha, concepto y renglones con su categoría y monto', () async {
    container.listen(expenseFormNotifierProvider, (_, __) {});
    final n = container.read(expenseFormNotifierProvider.notifier);
    await n.prefill(CorrectionSource(
      seq: 4,
      type: 2,
      date: DateTime(2026, 10, 21),
      concept: 'kiosco',
      accountLocalId: s.accounts['Efectivo'],
      amountCents: 0,
      lines: [(concept: 'pan', categoryLocalId: s.categories['Comida'], amountCents: 1500), (concept: 'leche', categoryLocalId: null, amountCents: 900)],
    ));
    final st = n.state;
    expect((st.selectedCuentaId, st.fecha, st.conceptoGeneral), (s.accounts['Efectivo'], DateTime(2026, 10, 21), 'kiosco'));
    expect(st.renglones.map((r) => (r.concepto, r.montoCents)), [('pan', 1500), ('leche', 900)]);
    expect(st.renglones.first.categoriaId, s.categories['Comida']);
  });

  test('transferencia: origen, destino de la misma moneda, monto, concepto y fecha; sin cuentas, quedan las de por defecto', () async {
    container.listen(transferFormNotifierProvider, (_, __) {});
    final n = container.read(transferFormNotifierProvider.notifier);
    await n.prefill(CorrectionSource(
      seq: 5,
      type: 3,
      date: DateTime(2026, 10, 22),
      concept: 'ahorro',
      fromLocalId: s.accounts['Banco'],
      toLocalId: s.accounts['Efectivo'],
      amountCents: 2000,
    ));
    expect((n.state.selectedOrigenId, n.state.selectedDestinoId), (s.accounts['Banco'], s.accounts['Efectivo']));
    expect((n.state.montoCents, n.state.concepto, n.state.fecha), (2000, 'ahorro', DateTime(2026, 10, 22)));

    final otro = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
    addTearDown(otro.dispose);
    otro.listen(transferFormNotifierProvider, (_, __) {});
    final m = otro.read(transferFormNotifierProvider.notifier);
    await m.cargarCuentas();
    final porDefecto = m.state.selectedOrigenId;
    await m.prefill(CorrectionSource(seq: 6, type: 3, date: DateTime(2026, 10, 23), concept: 'x', amountCents: 100));
    expect((m.state.selectedOrigenId, m.state.montoCents), (porDefecto, 100)); // queda la cuenta por defecto
  });
}
