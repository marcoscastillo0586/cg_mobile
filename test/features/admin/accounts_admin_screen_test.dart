// Pantalla "Cuentas" contra la base local REAL (ffi): alta, edición, activar/desactivar y baja quedan en la
// outbox; moneda fija con movimientos; permisos de invitado.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/features/accounts_admin/data/local_accounts_repository.dart';
import 'package:gastos_mobile/features/accounts_admin/presentation/screens/accounts_admin_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/admin_env.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  tearDown(() => CurrentDashboard.id.value = null);

  test('menú: quien puede editar edita y activa; sólo el dueño elimina', () {
    expect(accionesCuenta(canEdit: true, canDelete: true), ['edit', 'toggle', 'delete']);
    expect(accionesCuenta(canEdit: true, canDelete: false), ['edit', 'toggle']);
    expect(accionesCuenta(canEdit: false, canDelete: false), isEmpty);
  });

  Future<void> abrir(WidgetTester tester, {bool owner = true}) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await pumpScreen(tester, const AccountsAdminScreen(), settle: false, overrides: [
      ...adminOverrides(s, owner: owner),
      localAccountsRepositoryProvider.overrideWithValue(Future.value(LocalAccountsRepository(s.db))),
    ]);
    await settleIo(tester, 10);
  }

  Future<List<Map<String, Object?>>> ops(WidgetTester tester) async => (await tester.runAsync(() => s.db.query('outbox', orderBy: 'seq')))!;

  Future<void> menu(WidgetTester tester, String cuenta, String accion) async {
    await tester.tap(find.byKey(ValueKey('menu-cuenta-$cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(accion).last);
    await tester.pumpAndSettle();
  }

  testWidgets('filtro "Activas" oculta las inactivas', (tester) async {
    await abrir(tester);
    expect(find.text('CERRADA'), findsOneWidget);
    await tester.tap(find.textContaining('${l.active} ('));
    await tester.pump();
    expect(find.text('CERRADA'), findsNothing);
    await tester.tap(find.textContaining('${l.all} ('));
    await tester.pump();
    expect(find.text('CERRADA'), findsOneWidget);
  });

  testWidgets('alta en dólares: nombre, moneda e ícono a la outbox', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nueva-cuenta')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cuenta-nombre')), 'Billetera');
    await tester.tap(find.byKey(const ValueKey('cuenta-moneda')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cuenta-guardar')));
    await settleIo(tester, 10);
    final op = (await ops(tester)).single;
    expect(jsonDecode(op['data']! as String), containsPair('currency', 'USD'));
    expect(find.text('BILLETERA'), findsOneWidget);
  });

  testWidgets('editar una cuenta con movimientos: la moneda queda fija; cancelar no cambia nada', (tester) async {
    await abrir(tester);
    await menu(tester, 'Banco', l.edit);
    expect(find.text(l.currencyLockedAccountHasMovements), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(await ops(tester), isEmpty);
    await menu(tester, 'Banco', l.edit);
    await tester.enterText(find.byKey(const ValueKey('cuenta-nombre')), 'Banco Nación');
    await tester.tap(find.byKey(const ValueKey('cuenta-guardar')));
    await settleIo(tester, 10);
    final data = jsonDecode((await ops(tester)).single['data']! as String) as Map<String, dynamic>;
    expect(data, containsPair('name', 'Banco Nación'));
    expect(data.containsKey('currency'), isFalse);
  });

  testWidgets('activar, desactivar y eliminar con confirmación', (tester) async {
    await abrir(tester);
    await menu(tester, 'Cerrada', l.activate);
    await settleIo(tester, 10);
    expect(find.text(l.accountActivated), findsOneWidget);
    await menu(tester, 'Cerrada', l.deactivate);
    await settleIo(tester, 10);
    expect(find.text(l.accountDeactivated), findsOneWidget);
    await menu(tester, 'Cerrada', l.delete);
    await tester.tap(find.byKey(const ValueKey('confirmar-accion')));
    await settleIo(tester, 10);
    expect((await ops(tester)).length, 3);
  });

  testWidgets('invitado: edita las cuentas sin autor pero no elimina', (tester) async {
    await abrir(tester, owner: false);
    await tester.tap(find.byKey(const ValueKey('menu-cuenta-Banco')));
    await tester.pumpAndSettle();
    expect(find.text(l.edit), findsOneWidget);
    expect(find.text(l.delete), findsNothing);
  });
}
