// Ayudas para probar pantallas: la app con idiomas, rutas y providers simulados.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Monta [screen] en la ruta '/' de un GoRouter; cualquier otra ruta muestra su path ("→ /ruta"), para
/// comprobar a dónde navega la pantalla.
/// Con [pushed], '/' muestra "inicio" y la pantalla se abre encima (su `pop` vuelve a "inicio").
Future<GoRouter> pumpScreen(WidgetTester tester, Widget screen,
    {List<Override> overrides = const [], Locale locale = const Locale('es'), bool pushed = false, bool settle = true}) async {
  // Alto de celular (con el de prueba por defecto, 800×600, quedan botones fuera de la pantalla) y ancho
  // generoso: la fuente de los tests dibuja cada letra como un cuadrado y desbordaría un ancho real.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => pushed ? const Scaffold(body: Text('inicio')) : screen),
    GoRoute(path: '/pantalla', builder: (_, __) => screen),
    GoRoute(path: '/:a', builder: (_, s) => Scaffold(body: Text('→ ${s.uri.path}'))),
    GoRoute(path: '/:a/:b', builder: (_, s) => Scaffold(body: Text('→ ${s.uri.path}'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  // Sin [settle] (pantallas con indicador de carga mientras lee SQLite) se avanza un tiempo fijo.
  Future<void> wait() => settle ? tester.pumpAndSettle() : tester.pump(const Duration(milliseconds: 600));
  await wait();
  if (pushed) {
    unawaited(router.push('/pantalla'));
    await wait();
  }
  return router;
}

/// Repositorio de dashboards en memoria (sin servidor).
class FakeDashboardsRepository implements DashboardsRepository {
  List<Dashboard> dashboards;
  List<DashboardInvitation> pendingInvitations;
  List<AppNotification> pendingNotifications;
  bool online;
  final read = <int>[];
  FakeDashboardsRepository({this.dashboards = const [], this.pendingInvitations = const [], this.pendingNotifications = const [], this.online = true});

  Future<T> _call<T>(T Function() f) async => online ? f() : throw const NetworkException();

  @override
  Future<List<Dashboard>> list() => _call(() => dashboards);
  @override
  Future<List<Dashboard>> cached() async => dashboards;
  @override
  Future<List<DashboardInvitation>> invitations() => _call(() => pendingInvitations);
  @override
  Future<List<AppNotification>> notifications() => _call(() => pendingNotifications);
  final pendingNames = <String, String>{};
  @override
  Future<String?> readPendingName(String key) async => pendingNames[key];
  @override
  Future<void> savePendingName(String key, String? value) async => value == null ? pendingNames.remove(key) : pendingNames[key] = value;
  @override
  Future<void> markRead(int id) => _call(() {
        read.add(id);
        pendingNotifications = pendingNotifications.where((n) => n.id != id).toList();
      });

  /// Llamadas de gestión recibidas ("crear Casa", "invitar 3 a@b.c", ...).
  final calls = <String>[];
  List<DashboardMember> membersOf = const [];

  @override
  Future<Dashboard> create(String name) => _call(() {
        calls.add('crear $name');
        return Dashboard(id: 99, name: name, ownerUserId: 7, ownerName: 'Ana', principal: false, isOwner: true, membersCount: 1);
      });
  @override
  Future<Dashboard> rename(int id, String name) => _call(() {
        calls.add('renombrar $id $name');
        return dashboards.firstWhere((d) => d.id == id);
      });
  @override
  Future<void> invite(int id, String email) => _call(() => calls.add('invitar $id $email'));
  @override
  Future<List<DashboardMember>> members(int id) => _call(() => membersOf);
  @override
  Future<void> removeMember(int id, int userId) => _call(() => calls.add('quitar $id $userId'));
  @override
  Future<void> leave(int id) => _call(() => calls.add('salir $id'));
  @override
  Future<void> remove(int id) => _call(() => calls.add('eliminar $id'));
  @override
  Future<void> clear(int id) => _call(() => calls.add('limpiar $id'));
  @override
  Future<Dashboard> accept(int invitationId) => _call(() {
        calls.add('aceptar $invitationId');
        return dashboards.first;
      });
  @override
  Future<void> reject(int invitationId) => _call(() => calls.add('rechazar $invitationId'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un Future que nunca termina (para dependencias que la pantalla no llega a usar).
Future<T> never<T>() => Completer<T>().future;
