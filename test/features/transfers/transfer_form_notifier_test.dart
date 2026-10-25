// Formulario de transferencia contra SQLite REAL (ffi). No prueba la pantalla ni el celular.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/database/local_catalog.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:gastos_mobile/features/transfers/presentation/providers/transfer_form_notifier.dart';
import '../../helpers/local_seed.dart';

void main() {
  late SeededDb s;
  late ProviderContainer container;
  late TransferFormNotifier notifier;

  setUp(() async {
    s = await seededDb();
    container = ProviderContainer(overrides: [
      localCatalogProvider.overrideWithValue(s.catalog),
      localMovementWriterProvider.overrideWithValue(s.writer),
    ]);
    container.listen(transferFormNotifierProvider, (_, __) {});
    notifier = container.read(transferFormNotifierProvider.notifier);
    await notifier.cargarCuentas();
  });

  tearDown(() async {
    container.dispose();
    await s.db.close();
  });

  test('el destino solo ofrece cuentas de la misma moneda que el origen', () {
    notifier.setOrigen(s.accounts['Banco']!);
    expect(notifier.state.destinosValidos.map((c) => c.name), ['Efectivo']);
    expect(notifier.state.selectedDestinoId, s.accounts['Efectivo']);
    notifier.setDestino(s.accounts['Dolares']!); // ignorado: otra moneda
    expect(notifier.state.selectedDestinoId, s.accounts['Efectivo']);
    notifier.setOrigen(s.accounts['Dolares']!);
    expect(notifier.state.destinosValidos, isEmpty);
    expect(notifier.state.selectedDestinoId, isNull);
  });

  test('guarda el par en SQLite + outbox; los saldos locales se mueven', () async {
    notifier.setOrigen(s.accounts['Banco']!);
    notifier.setMonto(30000);
    expect(await notifier.realizarTransferencia(), isTrue);
    expect((await s.balance('Banco'), await s.balance('Efectivo')), (70000, 35000));
    expect(await s.count('outbox', "data LIKE '%\"type\":3%'"), 1);
  });

  test('aviso de fondos; el celular no la bloquea: queda en la cola y el servidor decide al enviarla (R2)', () async {
    notifier.setOrigen(s.accounts['Efectivo']!);
    notifier.setMonto(5001);
    expect(notifier.state.fondosInsuficientes, isTrue);
    expect(await notifier.realizarTransferencia(), isTrue);
    expect(await s.balance('Efectivo'), -1);
    expect(await s.count('outbox', "data LIKE '%\"type\":3%'"), 1);
  });
}
