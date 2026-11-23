// Pantalla "Ajustes": accesos, nombre para mostrar, idioma, moneda principal (aceptada o rechazada por el
// servidor), tema y diagnóstico de sesión, con la cuenta y el servidor SIMULADOS.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:gastos_mobile/features/settings/presentation/providers/settings_provider.dart';
import 'package:gastos_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../helpers/app_env.dart';
import '../../helpers/screen.dart';

const _ana = UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com', monedaPrincipal: 'ARS');

class _Auth implements AuthRepository {
  Object? error;
  final calls = <String>[];
  @override
  Stream<Object> get onSessionExpired => const Stream.empty();
  @override
  Future<UserEntity> updateDisplayName(String name) async {
    calls.add('nombre $name');
    if (error != null) throw error!;
    return UserEntity(idUsuario: 7, nombreUsuario: name, email: 'a@x.com');
  }

  @override
  Future<UserEntity> updateMainCurrency(String currency) async {
    calls.add('moneda $currency');
    if (error != null) throw error!;
    return UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com', monedaPrincipal: currency);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  setUp(() => CurrentAccount.id = 7);
  tearDown(() => CurrentAccount.id = null);

  Future<(_Auth, FakeServer)> abrir(WidgetTester tester, {bool offline = false}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = _Auth();
    final server = FakeServer();
    await pumpScreen(tester, const SettingsScreen(), overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      initialAuthStateProvider.overrideWithValue(AuthState.authenticated(_ana, offline: offline)),
      dioClientProvider.overrideWithValue(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1'),
    ]);
    return (auth, server);
  }

  Future<void> elegir(WidgetTester tester, Key key, String opcion) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcion).last);
    await tester.pumpAndSettle();
  }

  testWidgets('accesos a las pantallas de administración', (tester) async {
    await abrir(tester);
    await tester.tap(find.text(l.categories2));
    await tester.pumpAndSettle();
    expect(find.text('→ ${AppRoutes.categoriesAdmin}'), findsOneWidget);
  });

  testWidgets('nombre para mostrar: guardado; vacío o igual no llama; error se muestra', (tester) async {
    final (auth, _) = await abrir(tester);
    Future<void> escribir(String nombre) async {
      await tester.tap(find.byKey(const ValueKey('editar-nombre')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nombre-para-mostrar')), nombre);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
    }

    await escribir('  ');
    await escribir('Ana');
    expect(auth.calls, isEmpty);
    await escribir('Anita');
    expect(auth.calls, ['nombre Anita']);
    expect(find.text(l.displayNameSaved), findsOneWidget);
    auth.error = const ServerException('caído', 500, 'INTERNAL_ERROR');
    await escribir('Ana María');
    expect(find.textContaining('(INTERNAL_ERROR)'), findsOneWidget);
  });

  testWidgets('sin conexión lo indica junto al correo', (tester) async {
    await abrir(tester, offline: true);
    expect(find.text('a@x.com · ${l.offline}'), findsOneWidget);
  });

  testWidgets('moneda principal: aceptada se guarda; rechazada vuelve a la vigente', (tester) async {
    final (auth, _) = await abrir(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await elegir(tester, const ValueKey('moneda-principal-ARS-0'), l.currencyUsd);
    expect(auth.calls, ['moneda USD']);
    expect(container.read(settingsProvider).defaultCurrency, 'USD');
    expect(find.text(l.mainCurrencySaved), findsOneWidget);

    auth.error = const ServerException('caído', 500, 'INTERNAL_ERROR');
    await elegir(tester, const ValueKey('moneda-principal-USD-0'), l.currencyArs);
    expect(container.read(settingsProvider).defaultCurrency, 'USD');
    expect(find.byKey(const ValueKey('moneda-principal-USD-1')), findsOneWidget); // reconstruido con la vigente
  });

  testWidgets('idioma y tema se guardan en los ajustes', (tester) async {
    await abrir(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    await elegir(tester, const ValueKey('idioma'), 'English');
    expect(container.read(settingsProvider).language, 'en');
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('diagnóstico de sesión: dos pedidos en paralelo; con error, el motivo', (tester) async {
    final (_, server) = await abrir(tester);
    server.routes['/auth/me'] = (200, {'id': 7});
    await tester.tap(find.text(l.sessionDiagnosticsDebug));
    await tester.pumpAndSettle();
    expect(find.textContaining('OK: ids [7, 7]'), findsOneWidget);
    server.routes.remove('/auth/me');
    await tester.tap(find.text(l.sessionDiagnosticsDebug));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });
}
