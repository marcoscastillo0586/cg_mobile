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
Future<GoRouter> pumpScreen(WidgetTester tester, Widget screen, {List<Override> overrides = const [], Locale locale = const Locale('es')}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
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
  await tester.pumpAndSettle();
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
  @override
  Future<String?> readPendingName(String key) async => null;
  @override
  Future<void> savePendingName(String key, String? value) async {}
  @override
  Future<void> markRead(int id) => _call(() {
        read.add(id);
        pendingNotifications = pendingNotifications.where((n) => n.id != id).toList();
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un Future que nunca termina (para dependencias que la pantalla no llega a usar).
Future<T> never<T>() => Completer<T>().future;
