// Pantalla principal con saldos, sincronizador, avisos en vivo y cuenta SIMULADOS (sin red ni base real).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/dashboards/live_events.dart';
import 'package:gastos_mobile/core/database/local_database.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/core/sync/sync_controller.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:gastos_mobile/features/dashboard/data/budget_alerts_repository.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/balances.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/dashboard_notifier.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/novedades_notifier.dart';
import 'package:gastos_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import 'package:sqflite/sqflite.dart';
import '../../helpers/app_env.dart';
import '../../helpers/screen.dart';

const _cuentas = [
  BalanceAccount(id: 1, serverId: 10, name: 'Banco', currency: Currency.ars, imageUrl: null, iconRef: '01', balanceCents: 150000),
  BalanceAccount(id: 2, name: 'Caja nueva', currency: Currency.ars, imageUrl: null, iconRef: '02', balanceCents: 2500),
  BalanceAccount(id: 3, serverId: 30, name: 'Dólares', currency: Currency.usd, imageUrl: null, iconRef: '03', balanceCents: 4000),
];
const _casa = Dashboard(id: 1, name: 'Casa', ownerUserId: 7, ownerName: 'Ana', principal: true, isOwner: true, membersCount: 1);
const _oficina = Dashboard(id: 3, name: 'Oficina', ownerUserId: 8, ownerName: 'Beto', principal: true, isOwner: false, membersCount: 2);

class _Balances implements BalancesRepository {
  Object? error;
  final untils = <String?>[];
  @override
  Future<Balances> getBalances({String? until}) async {
    untils.add(until);
    if (error != null) throw error!;
    return Balances(until: until, accounts: _cuentas);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync extends SyncController {
  _Sync(super.ref);
  var syncs = 0;
  @override
  Future<void> sync({bool force = true}) async => syncs++;
  void emit(SyncState s) => state = s;
}

class _Novedades extends NovedadesNotifier {
  _Novedades() : super(never(), SecureStorageService(const FlutterSecureStorage()), BudgetAlertsRepository(DioClient()), () => null);
  var calculos = 0;
  @override
  Future<void> calcularNovedades() async => calculos++;
}

class _Auth implements AuthRepository {
  final monedas = <String>[];
  @override
  Future<UserEntity> updateMainCurrency(String currency) async {
    monedas.add(currency);
    return UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com', monedaPrincipal: currency);
  }

  @override
  Stream<Object> get onSessionExpired => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Live extends LiveEvents {
  final void Function(LiveEvent) emitForTest;
  _Live(this.emitForTest) : super(DioClient(), emitForTest);
  var running = false;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
}

class _Db implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Env {
  final balances = _Balances();
  final auth = _Auth();
  final novedades = _Novedades();
  final dashboards = FakeDashboardsRepository(dashboards: const [_casa, _oficina]);
  late _Sync sync;
  late _Live live;
  late DashboardNotifier saldos;
}

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  const metodo = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const cambios = EventChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger = TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  late StreamController<List<String>> red; // cambios de red del celular

  setUp(() {
    CurrentAccount.id = 7;
    red = StreamController<List<String>>.broadcast();
    messenger.setMockMethodCallHandler(metodo, (_) async => ['none']);
    messenger.setMockStreamHandler(cambios, MockStreamHandler.inline(onListen: (_, sink) {
      red.stream.listen(sink.success);
    }));
  });
  tearDown(() {
    red.close();
    messenger.setMockMethodCallHandler(metodo, null);
    messenger.setMockStreamHandler(cambios, null);
    CurrentAccount.id = null;
    CurrentDashboard.id.value = null;
    CurrentDashboard.notice.value = null;
    ServerReachability.markOnline();
  });

  Future<_Env> abrir(
    WidgetTester tester, {
    String? monedaServidor = 'ARS',
    Map<String, String> storage = const {'is_first_launch_done_u7': 'true', 'app_default_currency_u7': 'ARS'},
    Future<Database>? db,
    Object? errorSaldos,
  }) async {
    FlutterSecureStorage.setMockInitialValues(Map.of(storage));
    ServerReachability.markOnline();
    final env = _Env()..balances.error = errorSaldos;
    await pumpScreen(tester, const DashboardScreen(), settle: false, overrides: [
      dioClientProvider.overrideWithValue(DioClient(adapter: FakeServer())..dio.options.baseUrl = 'http://api.fake/api/v1'),
      localDatabaseProvider.overrideWithValue(db ?? Future.value(_Db())),
      balancesRepositoryProvider.overrideWithValue(env.balances),
      dashboardNotifierProvider.overrideWith((_) => env.saldos = DashboardNotifier(env.balances)),
      novedadesNotifierProvider.overrideWith((_) => env.novedades),
      syncControllerProvider.overrideWith((ref) => env.sync = _Sync(ref)),
      liveEventsProvider.overrideWithValue((on) => env.live = _Live(on)),
      authRepositoryProvider.overrideWithValue(env.auth),
      initialAuthStateProvider.overrideWithValue(
          AuthState.authenticated(UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com', monedaPrincipal: monedaServidor))),
      dashboardsRepositoryProvider.overrideWithValue(env.dashboards),
      dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(env.dashboards, 7)),
    ]);
    await settleIo(tester);
    return env;
  }

  testWidgets('saldos por moneda, cuentas y título del dashboard; al entrar sincroniza y calcula novedades', (tester) async {
    final env = await abrir(tester);
    expect(find.text('Casa'), findsWidgets); // con más de un dashboard, el título dice cuál
    expect(find.text(Money.format(152500)), findsWidgets);
    expect(find.text('BANCO'), findsOneWidget);
    expect(find.text(l.myAccountsAccounts(3)), findsOneWidget);
    expect(env.live.running, isTrue);
    expect(env.sync.syncs, greaterThanOrEqualTo(1)); // base abierta: descarga
    expect(env.novedades.calculos, greaterThanOrEqualTo(1));
    expect(env.auth.monedas, isEmpty); // el servidor ya tiene la misma moneda
  });

  testWidgets('accesos: formularios, historial, límites, informes y ajustes', (tester) async {
    await abrir(tester);
    for (final (tocar, ruta) in [
      (find.byIcon(Icons.analytics_outlined), AppRoutes.analytics),
      (find.byIcon(Icons.settings_outlined), AppRoutes.settings),
      (find.byKey(const ValueKey('ir-limites')), AppRoutes.limitsAdmin),
    ]) {
      await tester.tap(tocar);
      await tester.pumpAndSettle();
      expect(find.text('→ $ruta'), findsOneWidget);
      GoRouter.of(tester.element(find.text('→ $ruta'))).pop();
      await tester.pumpAndSettle();
    }
  });

  test('historial de una cuenta: filtrado por su id del servidor; sin enviar, el general', () {
    expect(historialDe(_cuentas[0]), '${AppRoutes.movements}?id_lugar=10&nombre=Banco');
    expect(historialDe(_cuentas[1]), AppRoutes.movements);
  });

  testWidgets('ocultar montos y desmarcar una cuenta cambian el total', (tester) async {
    final env = await abrir(tester);
    env.saldos.toggleCuentaSeleccionada(1);
    await tester.pump();
    expect(find.text(Money.format(2500)), findsWidgets);
    env.saldos.toggleVisibilidadMontos();
    await tester.pump();
    expect(find.text(Money.format(2500)), findsNothing);
  });

  testWidgets('filtro de fecha: elegir un día carga hasta ese día; "Limpiar" vuelve a hoy', (tester) async {
    final env = await abrir(tester);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text(l.apply));
    await settleIo(tester);
    expect(env.balances.untils.last, endsWith('-15'));
    await tester.tap(find.byIcon(Icons.filter_alt).first); // con filtro cambia el ícono
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.clear));
    await settleIo(tester);
    expect(env.balances.untils.last, isNull);
  });

  testWidgets('primera carga fallida: motivo y "Reintentar" vuelve a cargar', (tester) async {
    final env = await abrir(tester, errorSaldos: const ServerException('Caído', 503, 'TEMPORARY_ERROR'));
    expect(find.byKey(const ValueKey('dashboard-error')), findsOneWidget);
    final antes = env.balances.untils.length;
    env.balances.error = null;
    await tester.tap(find.text(l.retry));
    await settleIo(tester);
    expect(env.balances.untils.length, antes + 1);
    expect(find.text('BANCO'), findsOneWidget);
  });

  testWidgets('sincronización terminada recarga saldos y novedades; un error inesperado se avisa', (tester) async {
    final env = await abrir(tester);
    final (cargas, calculos) = (env.balances.untils.length, env.novedades.calculos);
    env.sync.emit(const SyncState(status: SyncStatus.syncing));
    env.sync.emit(const SyncState(status: SyncStatus.complete));
    await settleIo(tester);
    expect(env.balances.untils.length, cargas + 1);
    expect(env.novedades.calculos, calculos + 1);
    env.sync.emit(SyncState(status: SyncStatus.error, error: StateError('x')));
    await tester.pump();
    expect(find.textContaining(l.syncFailed2), findsOneWidget);
  });

  testWidgets('avisos en vivo: invitación, notificación, cambios del dashboard visto y de la lista', (tester) async {
    final env = await abrir(tester);
    final emit = env.live;
    final antes = env.sync.syncs;
    void evento(String type, [int? id]) => emit.emitForTest(LiveEvent(type, id));
    evento('invitation');
    evento('notification');
    evento('dashboard-changed', 3); // otro dashboard: no sincroniza
    expect(env.sync.syncs, antes);
    evento('dashboard-changed', 1);
    expect(env.sync.syncs, antes + 1);
    evento('access-removed');
    await settleIo(tester);
    expect(env.dashboards.calls, isEmpty); // solo lecturas
  });

  testWidgets('invitación pendiente: la ventana aparece sola una vez', (tester) async {
    final env = await abrir(tester);
    env.dashboards.pendingInvitations = const [
      DashboardInvitation(id: 5, dashboardId: 3, dashboardName: 'Oficina', inviterName: 'Beto', inviterEmail: 'b@x.com'),
    ];
    env.live.emitForTest(const LiveEvent('invitation', null));
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(find.text(l.invitationBody('Beto', 'b@x.com', 'Oficina')), findsOneWidget);
  });

  testWidgets('volver a la app sincroniza y reconecta; salir corta los avisos', (tester) async {
    final env = await abrir(tester);
    final antes = env.sync.syncs;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(env.live.running, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleIo(tester);
    expect(env.live.running, isTrue);
    expect(env.sync.syncs, antes + 1);
    await tester.pump(const Duration(seconds: 31)); // ciclo automático
    expect(env.sync.syncs, antes + 2);
  });

  testWidgets('volver a tener red sincroniza enseguida', (tester) async {
    final env = await abrir(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); // sólo con la app visible
    await settleIo(tester);
    final antes = env.sync.syncs;
    red.add(['wifi']);
    await settleIo(tester);
    expect(env.sync.syncs, antes + 1);
    red.add(['wifi']); // ya tenía red: nada
    await settleIo(tester);
    expect(env.sync.syncs, antes + 1);
  });

  testWidgets('sin moneda en el servidor se envía la del celular; con otra, manda la del servidor', (tester) async {
    final env = await abrir(tester, monedaServidor: null);
    expect(env.auth.monedas, ['ARS']);
    await tester.pumpWidget(const SizedBox());
    final env2 = await abrir(tester, monedaServidor: 'USD');
    expect(env2.auth.monedas, isEmpty);
    expect(find.text(Money.format(4000, currency: Currency.usd)), findsWidgets); // total principal en dólares
  });

  testWidgets('primer ingreso: el diálogo guarda moneda, idioma y nombre del dashboard', (tester) async {
    final env = await abrir(tester, storage: const {});
    expect(find.byKey(const ValueKey('onboarding-nombre-dashboard')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onboarding-nombre-dashboard')), 'Hogar');
    await tester.tap(find.byType(ElevatedButton).last);
    await settleIo(tester);
    expect(env.auth.monedas, ['ARS']);
    expect(env.dashboards.calls, contains('renombrar 1 Hogar'));
  });

  testWidgets('base local que no abre: se avisa', (tester) async {
    await abrir(tester, db: Future<Database>.error(StateError('disco lleno'))..ignore());
    await tester.pump();
    expect(find.textContaining('disco lleno'), findsOneWidget);
  });

  testWidgets('acceso perdido al dashboard elegido: aviso único', (tester) async {
    await abrir(tester);
    CurrentDashboard.notice.value = CurrentDashboard.accessLost;
    await tester.pump();
    expect(find.text(l.accessLostNotice), findsOneWidget);
    expect(CurrentDashboard.notice.value, isNull);
  });
}
