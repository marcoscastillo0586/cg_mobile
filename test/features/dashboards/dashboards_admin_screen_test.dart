// Pantalla "Dashboards": crear, renombrar, compartir, integrantes, limpiar/eliminar y salir, con un repositorio
// en memoria (sin servidor).
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_admin_screen.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';

const _principal = Dashboard(id: 1, name: 'Casa', ownerUserId: 7, ownerName: 'Ana', principal: true, isOwner: true, membersCount: 2);
const _viaje = Dashboard(id: 2, name: 'Viaje', ownerUserId: 7, ownerName: 'Ana', principal: false, isOwner: true, membersCount: 1);
const _ajeno = Dashboard(id: 3, name: 'Oficina', ownerUserId: 8, ownerName: 'Beto', principal: true, isOwner: false, membersCount: 2);

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  Future<FakeDashboardsRepository> abrir(WidgetTester tester, {List<DashboardMember> members = const []}) async {
    FlutterSecureStorage.setMockInitialValues({});
    ServerReachability.markOnline();
    final repo = FakeDashboardsRepository(dashboards: const [_principal, _viaje, _ajeno])..membersOf = members;
    await pumpScreen(tester, const DashboardsAdminScreen(), overrides: [
      dashboardsRepositoryProvider.overrideWithValue(repo),
      dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(repo, 7)),
    ]);
    return repo;
  }

  Future<void> confirmar(WidgetTester tester, String accion) async {
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, accion)));
    await tester.pumpAndSettle();
  }

  testWidgets('propios y compartidos con su dueño; detalle de principal y compartido', (tester) async {
    await abrir(tester);
    expect(find.byKey(const ValueKey('dashboard-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-2')), findsOneWidget);
    expect(find.text(l.ownedBy('Beto')), findsOneWidget);
    expect(find.textContaining(l.dashboardSharedCount(2)), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.text(l.clearDashboard), findsOneWidget); // el principal se limpia
    expect(find.text(l.deleteDashboard), findsOneWidget); // los demás se eliminan
  });

  testWidgets('crear, renombrar y compartir por correo', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.text(l.createDashboard));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty); // sin nombre no hace nada
    await tester.enterText(find.byKey(const ValueKey('nuevo-dashboard')), ' Ahorro ');
    await tester.tap(find.text(l.createDashboard));
    await tester.pumpAndSettle();
    expect(find.text(l.dashboardCreated('Ahorro')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('renombrar-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Vacaciones');
    await confirmar(tester, l.save);

    await tester.enterText(find.byKey(const ValueKey('compartir-2')), 'beto@x.com');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('dashboard-2')), matching: find.text(l.shareDashboard)));
    await tester.pumpAndSettle();
    expect(repo.calls, ['crear Ahorro', 'renombrar 2 Vacaciones', 'invitar 2 beto@x.com']);
    expect(find.text(l.invitationSent('beto@x.com')), findsOneWidget);
  });

  testWidgets('integrantes: quitar acceso pide confirmar', (tester) async {
    final repo = await abrir(tester, members: const [
      DashboardMember(userId: 7, name: 'Ana', email: 'ana@x.com', isOwner: true),
      DashboardMember(userId: 9, name: 'Caro', email: 'caro@x.com', isOwner: false),
    ]);
    expect(find.text('Ana (${l.ownerTag})'), findsWidgets);
    await tester.tap(find.text(l.removeAccess).first);
    await confirmar(tester, l.cancel);
    expect(repo.calls, isEmpty);
    await tester.tap(find.text(l.removeAccess).first);
    await confirmar(tester, l.removeAccess);
    expect(repo.calls.first, startsWith('quitar '));
  });

  testWidgets('limpiar el principal, eliminar otro y salir de uno compartido, cada uno con confirmación', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.text(l.clearDashboard));
    await confirmar(tester, l.clearDashboard);
    await tester.tap(find.text(l.deleteDashboard));
    await confirmar(tester, l.deleteDashboard);
    await tester.tap(find.text(l.leaveDashboard));
    await confirmar(tester, l.leaveDashboard);
    expect(repo.calls, ['limpiar 1', 'eliminar 2', 'salir 3']);
  });

  testWidgets('sin conexión la acción falla y se muestra el motivo', (tester) async {
    final repo = await abrir(tester);
    repo.online = false;
    await tester.enterText(find.byKey(const ValueKey('nuevo-dashboard')), 'Ahorro');
    await tester.tap(find.text(l.createDashboard));
    await tester.pumpAndSettle();
    expect(find.text(l.errNetwork), findsOneWidget);
  });
}
