// Selector de dashboards de la barra y ventana de invitación recibida, con un repositorio en memoria.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboard_widgets.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

const _casa = Dashboard(id: 1, name: 'Casa', ownerUserId: 7, ownerName: 'Ana', principal: true, isOwner: true, membersCount: 1);
const _oficina = Dashboard(id: 3, name: 'Oficina', ownerUserId: 8, ownerName: 'Beto', principal: true, isOwner: false, membersCount: 2);
const _invitacion = DashboardInvitation(id: 5, dashboardId: 3, dashboardName: 'Oficina', inviterName: 'Beto', inviterEmail: 'beto@x.com');

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  tearDown(() => CurrentDashboard.id.value = null);

  Future<FakeDashboardsRepository> abrir(WidgetTester tester, Widget Function(BuildContext, WidgetRef) body) async {
    FlutterSecureStorage.setMockInitialValues({});
    ServerReachability.markOnline();
    final s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    final repo = FakeDashboardsRepository(dashboards: const [_casa, _oficina], pendingInvitations: const [_invitacion]);
    await pumpScreen(
      tester,
      Scaffold(appBar: AppBar(actions: const [DashboardSelector()]), body: Consumer(builder: (c, r, _) => body(c, r))),
      overrides: [
        ...localAppOverrides(s, FakeServer()),
        dashboardsRepositoryProvider.overrideWithValue(repo),
        dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(repo, 7)),
      ],
    );
    return repo;
  }

  testWidgets('selector: lista con el elegido marcado y "Administrar"; elegir otro cambia de dashboard', (tester) async {
    await abrir(tester, (_, __) => const SizedBox());
    await tester.tap(find.byKey(const ValueKey('selector-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Oficina · ${l.dashboardSharedTag}'), findsOneWidget);
    expect(tester.widget<CheckedPopupMenuItem<Object>>(find.ancestor(of: find.text('Casa'), matching: find.byType(CheckedPopupMenuItem<Object>))).checked, isTrue);
    await tester.tap(find.text('Oficina · ${l.dashboardSharedTag}'));
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(CurrentDashboard.id.value, 3);
  });

  testWidgets('selector: "Administrar dashboards" abre la pantalla', (tester) async {
    await abrir(tester, (_, __) => const SizedBox());
    await tester.tap(find.byKey(const ValueKey('selector-dashboard')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.manageDashboards));
    await tester.pumpAndSettle();
    expect(find.text('→ /admin/dashboards'), findsOneWidget);
  });

  Widget boton(BuildContext context, WidgetRef ref) => TextButton(onPressed: () => showInvitationDialog(context, ref, _invitacion), child: const Text('ver'));

  testWidgets('invitación: rechazar la saca; aceptar pasa al dashboard compartido', (tester) async {
    final repo = await abrir(tester, boton);
    await tester.tap(find.text('ver'));
    await tester.pumpAndSettle();
    expect(find.text(l.invitationBody('Beto', 'beto@x.com', 'Oficina')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rechazar-invitacion')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aceptar-invitacion')));
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, ['rechazar 5', 'aceptar 5']);
    expect(CurrentDashboard.id.value, 1); // el que devuelve el servidor simulado
  });

  testWidgets('invitación sin conexión: cierra y muestra el motivo', (tester) async {
    final repo = await abrir(tester, boton);
    repo.online = false;
    await tester.tap(find.text('ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aceptar-invitacion')));
    await tester.pumpAndSettle();
    expect(find.text(l.errNetwork), findsOneWidget);
    await tester.tap(find.text('ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rechazar-invitacion')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
