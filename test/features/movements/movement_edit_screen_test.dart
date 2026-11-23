// Pantalla "Editar movimiento" contra la base local REAL (ffi): cada cambio queda en la outbox.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/movements/presentation/screens/movement_edit_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  tearDown(() => ServerReachability.markOnline());

  Future<void> sembrar() async {
    final h = await s.db.insert('movement_headers', {'server_id': 900, 'type': 2, 'occurred_at': '2026-10-10 10:00:00', 'general_concept': 'Super', 'updated_at': 'x'});
    await s.db.insert('movement_details', {'server_id': 9001, 'header_local_id': h, 'account_local_id': s.accounts['Efectivo'], 'category_local_id': s.categories['Comida'], 'amount_cents': -1000, 'concept': 'Pan', 'updated_at': 'x'});
    await s.db.insert('movement_details', {'server_id': 9002, 'header_local_id': h, 'account_local_id': s.accounts['Efectivo'], 'category_local_id': s.categories['Super'], 'amount_cents': -500, 'concept': 'Leche', 'updated_at': 'x'});
    final t = await s.db.insert('movement_headers', {'server_id': 901, 'type': 3, 'occurred_at': '2026-10-11 10:00:00', 'general_concept': 'Transferencia', 'updated_at': 'x'});
    await s.db.insert('movement_details', {'server_id': 9011, 'header_local_id': t, 'account_local_id': s.accounts['Banco'], 'category_local_id': s.categories['Transferencia'], 'amount_cents': -2000, 'updated_at': 'x'});
    await s.db.insert('movement_details', {'server_id': 9012, 'header_local_id': t, 'account_local_id': s.accounts['Efectivo'], 'category_local_id': s.categories['Transferencia'], 'amount_cents': 2000, 'updated_at': 'x'});
  }

  Future<void> abrir(WidgetTester tester, int serverId, {bool askDelete = false}) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await tester.runAsync(sembrar);
    await pumpScreen(tester, MovementEditScreen(serverId: serverId, askDelete: askDelete),
        overrides: localAppOverrides(s, FakeServer()), pushed: true, settle: false);
    await settleIo(tester);
    ServerReachability.markOnline();
  }

  Future<List<Map<String, Object?>>> ops(WidgetTester tester) async => (await tester.runAsync(() => s.db.query('outbox', orderBy: 'seq')))!;
  Future<void> tocar(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(key)));
    await settleIo(tester, 8);
  }

  testWidgets('comprobante que ya no está en el celular', (tester) async {
    await abrir(tester, 999);
    expect(find.text(l.movementNotPhoneWasDeleted), findsOneWidget);
  });

  testWidgets('encabezado: cambiar el concepto general lo encola', (tester) async {
    await abrir(tester, 900);
    await tester.enterText(find.byKey(const ValueKey('editar-concepto')), 'Almacén');
    await tocar(tester, 'guardar-encabezado');
    final op = (await ops(tester)).single;
    expect((op['entity'], op['action']), ('movement', 'update'));
    expect(jsonDecode(op['data']! as String), {'generalConcept': 'Almacén'});
  });

  testWidgets('renglón: monto inválido avisa; guardar y borrar renglones los encolan', (tester) async {
    await abrir(tester, 900);
    final pan = (await tester.runAsync(() => s.db.query('movement_details', where: 'server_id = 9001')))!.single['local_id'];
    final leche = (await tester.runAsync(() => s.db.query('movement_details', where: 'server_id = 9002')))!.single['local_id'];
    await tester.enterText(find.byKey(ValueKey('monto-renglon-$pan')), 'abc');
    await tocar(tester, 'guardar-renglon-$pan');
    expect(find.text(l.invalidAmountMax2Decimals), findsOneWidget);
    expect(await ops(tester), isEmpty);
    await tester.enterText(find.byKey(ValueKey('monto-renglon-$pan')), '12');
    await tocar(tester, 'guardar-renglon-$pan');
    expect(jsonDecode((await ops(tester)).single['data']! as String), {'amount': '12.00'});
    await tocar(tester, 'borrar-renglon-$leche');
    expect((await ops(tester)).last['action'], 'delete');
  });

  testWidgets('renglón con saldo que queda negativo y con conexión: pide confirmar', (tester) async {
    await abrir(tester, 900);
    final pan = (await tester.runAsync(() => s.db.query('movement_details', where: 'server_id = 9001')))!.single['local_id'];
    await tester.enterText(find.byKey(ValueKey('monto-renglon-$pan')), '9000');
    await tocar(tester, 'guardar-renglon-$pan');
    expect(find.text(l.balanceWillNegative), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await settleIo(tester);
    expect(await ops(tester), isEmpty);
    await tocar(tester, 'guardar-renglon-$pan');
    await tester.tap(find.byKey(const ValueKey('guardar-igual')));
    await settleIo(tester, 8);
    expect((await ops(tester)).single['entity'], 'movement_detail');
  });

  testWidgets('transferencia: monto inválido avisa; uno válido encola el par', (tester) async {
    await abrir(tester, 901);
    await tester.enterText(find.byKey(const ValueKey('editar-monto-transferencia')), 'x');
    await tocar(tester, 'guardar-transferencia');
    expect(find.text(l.completeSourceDestinationValidAmount), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('editar-monto-transferencia')), '30');
    await tocar(tester, 'guardar-transferencia');
    final data = jsonDecode((await ops(tester)).single['data']! as String) as Map<String, dynamic>;
    expect(data['transfer'], containsPair('amount', '30.00'));
  });

  testWidgets('eliminar el comprobante pide confirmar, lo encola y vuelve', (tester) async {
    await abrir(tester, 900);
    await tocar(tester, 'eliminar-comprobante');
    expect(find.text(l.removedAllItsLines), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmar-eliminar')));
    await settleIo(tester, 8);
    expect((await ops(tester)).single['action'], 'delete');
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('abrir desde "Eliminar" de la lista muestra la confirmación enseguida', (tester) async {
    await abrir(tester, 900, askDelete: true);
    expect(find.text(l.removedAllItsLines), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await settleIo(tester);
    expect(await ops(tester), isEmpty);
  });
}
