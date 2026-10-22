// Formulario de ingreso contra SQLite REAL (ffi). No prueba la pantalla ni el celular.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/features/incomes/presentation/providers/income_form_notifier.dart';
import 'package:gastos_mobile/features/incomes/presentation/providers/income_form_state.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late ProviderContainer container;
  late IncomeFormNotifier notifier;

  setUp(() async {
    s = await seededDb();
    container = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
    container.listen(incomeFormNotifierProvider, (_, __) {});
    notifier = container.read(incomeFormNotifierProvider.notifier);
    await notifier.cargarCuentas();
  });

  tearDown(() async {
    container.dispose();
    await s.db.close();
  });

  test('carga las cuentas activas locales, sin cuenta elegida', () {
    expect(notifier.state.status, IncomeFormStatus.ready);
    expect(notifier.state.cuentas.map((c) => c.name), ['Banco', 'Dolares', 'Efectivo']);
    expect(notifier.state.selectedCuentaId, isNull);
  });

  test('guarda en SQLite + outbox y suma al saldo local; concepto vacío usa el de siempre', () async {
    notifier.setCuenta(s.accounts['Efectivo']!);
    notifier.setMonto(250050);
    expect(await notifier.guardarIngreso(), isTrue);
    expect(await s.balance('Efectivo'), 5000 + 250050);
    expect(await s.count('outbox', "status = 'pending' AND data LIKE '%\"type\":1%'"), 1);
    expect(await s.count('movement_headers', "general_concept = '$conceptoIngresoPorDefecto'"), 1);
  });

  test('monto cero o sin cuenta: error y nada escrito', () async {
    notifier.setMonto(100);
    expect(await notifier.guardarIngreso(), isFalse);
    expect((notifier.state.error! as Failure).code, 'VALIDATION_ERROR');
    notifier.setCuenta(s.accounts['Banco']!);
    notifier.setMonto(0);
    expect(await notifier.guardarIngreso(), isFalse);
    expect((notifier.state.error! as Failure).code, 'VALIDATION_ERROR');
    expect(await s.count('outbox'), 0);
  });
}
