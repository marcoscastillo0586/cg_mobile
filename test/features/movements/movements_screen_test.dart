// Historial: cuándo una sincronización actualiza la lista.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';
import 'package:gastos_mobile/core/sync/pull_service.dart';
import 'package:gastos_mobile/core/sync/sync_controller.dart';
import 'package:gastos_mobile/features/movements/presentation/screens/movements_screen.dart';

SyncState _fin({int movs = 0, int borrados = 0, SyncStatus status = SyncStatus.complete}) => SyncState(
      status: status,
      lastResult: PullResult(full: false, pages: 1, movementsApplied: movs, deletedApplied: borrados, mismatches: const []),
    );

void main() {
  const enCurso = SyncState(status: SyncStatus.syncing);

  test('se actualiza si la sincronización terminó y trajo movimientos nuevos o borrados', () {
    expect(trajoMovimientos(enCurso, _fin(movs: 2)), isTrue);
    expect(trajoMovimientos(enCurso, _fin(borrados: 1)), isTrue);
  });

  test('no se actualiza sin cambios, sin terminar, sin conexión o sin resultado', () {
    expect(trajoMovimientos(enCurso, _fin()), isFalse);
    expect(trajoMovimientos(const SyncState(), _fin(movs: 2)), isFalse); // no venía sincronizando
    expect(trajoMovimientos(enCurso, _fin(movs: 2, status: SyncStatus.offline)), isFalse);
    expect(trajoMovimientos(enCurso, const SyncState(status: SyncStatus.complete)), isFalse);
  });

  testWidgets('abierto desde una cuenta: filtro con su nombre; quitarlo muestra todo', (tester) async {
    final l = lookupAppLocalizations(const Locale('es'));
    final s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    await pumpScreen(tester, const MovementsScreen(initialLugarId: 1, initialLugarNombre: 'Banco'),
        settle: false, overrides: localAppOverrides(s, FakeServer()));
    await settleIo(tester, 10);
    expect(find.widgetWithText(InputChip, 'Banco'), findsOneWidget);
    expect(find.textContaining(l.results), findsOneWidget);
    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!(); // la cruz del filtro
    await settleIo(tester, 10);
    expect(find.byType(InputChip), findsNothing);
    expect(find.text(l.lastMovements(3)), findsOneWidget);
  });
}
