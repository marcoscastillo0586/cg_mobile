// "Pendientes y rechazados" contra la base local REAL (ffi): motivo, corregir, descartar y vacío. Los
// rechazos se simulan como los deja PushService; no hay red.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/sync/outbox_repository.dart';
import 'package:gastos_mobile/core/sync/push_service.dart';
import 'package:gastos_mobile/features/movements/data/local_movement_writer.dart';
import 'package:gastos_mobile/features/sync/presentation/pending_operations_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

OutboxEntry _op({String? code, String? message}) => OutboxEntry(
    seq: 1, opId: 'x', entity: 'movement', action: 'create', status: 'rejected', attempts: 1, errorCode: code, errorMessage: message, description: 'd', createdAt: 'x');

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  test('motivo: traducido con su código; sin repetirlo; validación con su texto; sin código, nada', () {
    expect(motivoDe(_op(code: 'ACCOUNT_INACTIVE'), l), startsWith('${l.reason}: '));
    expect(motivoDe(_op(code: 'ACCOUNT_INACTIVE'), l), endsWith(' (ACCOUNT_INACTIVE)'));
    expect(motivoDe(_op(code: 'RARO', message: 'algo'), l)!.split('(RARO)').length, 2); // una sola vez
    expect(motivoDe(_op(code: 'VALIDATION_ERROR', message: 'Monto inválido'), l), '${l.reason}: Monto inválido');
    expect(motivoDe(_op(), l), isNull);
  });

  test('corregir abre el formulario del tipo de comprobante', () {
    expect(rutaDeCorreccion(2), AppRoutes.expensesCreate);
    expect(rutaDeCorreccion(1), AppRoutes.incomesCreate);
    expect(rutaDeCorreccion(3), AppRoutes.transfersCreate);
  });

  Future<void> abrir(WidgetTester tester, {bool rechazar = true, bool conflicto = false}) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await tester.runAsync(() async {
      final m = await (await s.writer).createExpense(ExpenseDraft(
          accountLocalId: s.accounts['Efectivo']!, date: DateTime(2026, 10, 21), generalConcept: 'kiosco',
          lines: [ExpenseLine(concept: 'pan', categoryLocalId: s.categories['Comida']!, amountCents: 1500)]));
      if (conflicto) {
        await s.db.update('outbox', {'status': 'conflict', 'attempts': 1, 'server_result': jsonEncode({'status': 'conflict', 'error': {'code': 'VERSION_CONFLICT', 'message': 'x'}})},
            where: 'op_id = ?', whereArgs: [m.opId]);
        return;
      }
      if (!rechazar) return;
      final op = (await s.db.query('outbox', where: 'op_id = ?', whereArgs: [m.opId])).single;
      await s.db.transaction((txn) async {
        await PushService.revert(txn, op);
        await txn.update('outbox', {
          'status': 'rejected', 'attempts': 1,
          'server_result': jsonEncode({'status': 'rejected', 'error': {'code': 'ACCOUNT_INACTIVE', 'message': 'motivo'}}),
        }, where: 'op_id = ?', whereArgs: [m.opId]);
      });
    });
    await pumpScreen(tester, const PendingOperationsScreen(), settle: false, overrides: localAppOverrides(s, FakeServer()));
    await settleIo(tester, 8);
  }

  testWidgets('rechazado: motivo, intentos y acciones; corregir abre el egreso', (tester) async {
    await abrir(tester);
    expect(find.textContaining('kiosco'), findsOneWidget);
    expect(find.textContaining('(ACCOUNT_INACTIVE)'), findsOneWidget);
    expect(find.text('${l.attempts}: 1'), findsOneWidget);
    await tester.tap(find.text(l.correct));
    await settleIo(tester, 8);
    await tester.pumpAndSettle();
    expect(find.text('→ ${AppRoutes.expensesCreate}'), findsOneWidget);
  });

  testWidgets('descartar pide confirmar; confirmado, la lista queda vacía', (tester) async {
    await abrir(tester);
    await tester.tap(find.text(l.discard2));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(find.textContaining('kiosco'), findsOneWidget);
    await tester.tap(find.text(l.discard2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-accion')));
    await settleIo(tester, 10);
    expect(find.text(l.discarded), findsOneWidget);
    expect(find.text(l.nothingPendingEverythingWasApplied), findsOneWidget);
  });

  testWidgets('pendiente nunca enviado: se puede descartar, no corregir', (tester) async {
    await abrir(tester, rechazar: false);
    expect(find.textContaining('${l.pending2} · #'), findsOneWidget);
    expect(find.text(l.correct), findsNothing);
    expect(find.text(l.discard2), findsOneWidget);
  });

  testWidgets('en conflicto: "Conservar la del servidor" y el aviso propio de conflicto', (tester) async {
    await abrir(tester, conflicto: true);
    expect(find.textContaining(l.conflictServerVersionApplied), findsOneWidget);
    await tester.tap(find.text(l.keepServerVersion));
    await tester.pumpAndSettle();
    expect(find.text(l.serverVersionKeptChangeLost), findsOneWidget);
    expect(find.text(l.removedPhoneLocalBalanceReverted), findsNothing);
  });

  testWidgets('descartar un rechazado explica que se revierte el saldo local', (tester) async {
    await abrir(tester);
    await tester.tap(find.text(l.discard2));
    await tester.pumpAndSettle();
    expect(find.text(l.removedPhoneLocalBalanceReverted), findsOneWidget);
    expect(find.text(l.serverVersionKeptChangeLost), findsNothing);
  });

  testWidgets('el botón de sincronizar está activo mientras no se sincroniza', (tester) async {
    await abrir(tester);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.sync_rounded)).onPressed, isNotNull);
  });
}
