// Panel de novedades: avisos de límites y de invitaciones respondidas, y qué pasa al tocarlos.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/dashboard/data/budget_alerts_repository.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/novedad_entity.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/dashboard/presentation/widgets/novedades_bottom_sheet.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';

class _Novedades extends NovedadesNotifier {
  final marked = <String>[];
  _Novedades(List<NovedadEntity> items)
      : super(never(), SecureStorageService(const FlutterSecureStorage()), BudgetAlertsRepository(DioClient()), () => null) {
    state = NovedadesState(novedades: items);
  }

  @override
  Future<void> calcularNovedades() async {}

  @override
  Future<void> marcarComoVista(NovedadEntity novedad) async => marked.add(novedad.idKey);
}

NovedadEntity _novedad(String key, NovedadTipo tipo, int pct, {bool vista = false}) => NovedadEntity(
      idKey: key, idLimiteGasto: 1, titulo: 'Comida', tipo: tipo, porcentaje: pct,
      desde: DateTime(2026, 11, 1), hasta: DateTime(2026, 11, 30), vista: vista,
    );

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  Future<(_Novedades, FakeDashboardsRepository)> abrir(WidgetTester tester, List<NovedadEntity> items, List<AppNotification> avisos) async {
    FlutterSecureStorage.setMockInitialValues({});
    final novedades = _Novedades(items);
    final repo = FakeDashboardsRepository(pendingNotifications: avisos);
    await pumpScreen(
      tester,
      Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => NovedadesBottomSheet.show(c), child: const Text('abrir')))),
      overrides: [
        novedadesNotifierProvider.overrideWith((_) => novedades),
        dashboardsRepositoryProvider.overrideWithValue(repo),
        dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(repo, 7)),
      ],
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return (novedades, repo);
  }

  testWidgets('sin novedades ni avisos: mensaje de vacío', (tester) async {
    await abrir(tester, [], []);
    expect(find.text(l.noPendingNotifications), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text(l.notifications), findsNothing);
  });

  testWidgets('texto e ícono por tipo; tocar una novedad la marca como vista y abre Límites', (tester) async {
    final (novedades, _) = await abrir(tester, [
      _novedad('a', NovedadTipo.alcanzado, 120),
      _novedad('b', NovedadTipo.cerca, 80, vista: true),
      _novedad('c', NovedadTipo.vencido, 30),
    ], []);
    expect(find.text(l.limitReached('Comida', 120)), findsOneWidget);
    expect(find.text(l.limitNearTop('Comida', 80)), findsOneWidget);
    expect(find.text(l.limitHasFinishedExpired('Comida')), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
    await tester.tap(find.text(l.limitNearTop('Comida', 80)));
    await tester.pumpAndSettle();
    expect(novedades.marked, ['b']);
    expect(find.text('→ /admin/limits'), findsOneWidget);
  });

  testWidgets('aviso de invitación aceptada o rechazada: al tocarlo se marca leído y desaparece', (tester) async {
    final (_, repo) = await abrir(tester, [], const [
      AppNotification(id: 1, accepted: true, userName: 'Ana', dashboardName: 'Casa'),
      AppNotification(id: 2, accepted: false, userName: 'Beto', dashboardName: 'Viaje'),
    ]);
    expect(find.text(l.notificationAccepted('Ana', 'Casa')), findsOneWidget);
    expect(find.text(l.notificationRejected('Beto', 'Viaje')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('aviso-1')));
    await tester.pumpAndSettle();
    expect(repo.read, [1]);
    expect(find.text(l.notificationAccepted('Ana', 'Casa')), findsNothing);
  });

  testWidgets('si no se puede marcar el aviso, se muestra el error y el aviso queda', (tester) async {
    final (_, repo) = await abrir(tester, [], const [AppNotification(id: 1, accepted: true, userName: 'Ana', dashboardName: 'Casa')]);
    repo.online = false;
    await tester.tap(find.byKey(const ValueKey('aviso-1')));
    await tester.pumpAndSettle();
    expect(find.text(l.notificationAccepted('Ana', 'Casa')), findsOneWidget);
    expect(find.text(l.errNetwork), findsOneWidget);
  });
}
