// Pantalla de ingreso con el repositorio de auth SIMULADO: validación, rechazo con código, avisos y servidor
// sin configurar.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:gastos_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';

class _Auth implements AuthRepository {
  final logins = <(String, String)>[];
  Object? error;
  Completer<void>? gate;

  @override
  Future<UserEntity> login(String email, String password) async {
    logins.add((email, password));
    await gate?.future;
    if (error != null) throw error!;
    return UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: email);
  }

  @override
  Stream<Object> get onSessionExpired => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  test('validaciones de correo y contraseña', () {
    expect(validarEmail(' ', l), l.enterEmail);
    expect(validarEmail('ana', l), l.invalidEmail);
    expect(validarEmail(' ana@x.com ', l), isNull);
    expect(validarPassword('', l), l.enterPassword);
    expect(validarPassword(' ', l), isNull); // un espacio puede ser la contraseña
  });

  test('avisos de sesión: vencida; cerrada sin revocar (con y sin detalle); ninguno', () {
    expect(avisoDeSesion(AuthState.unauthenticated(notice: AuthNotice.sessionExpired), l), l.sessionExpiredPleaseSignAgain);
    expect(avisoDeSesion(AuthState.unauthenticated(notice: AuthNotice.logoutNotRevoked), l), l.signedOutDeviceButServer(''));
    expect(avisoDeSesion(AuthState.unauthenticated(notice: AuthNotice.logoutNotRevoked, noticeError: const NetworkException('x')), l),
        l.signedOutDeviceButServer(' (${l.errNetwork})'));
    expect(avisoDeSesion(AuthState.unauthenticated(), l), isNull);
  });

  Future<_Auth> abrir(WidgetTester tester, {String? servidor = 'http://api.fake/api/v1', AuthState? estado}) async {
    final auth = _Auth();
    await pumpScreen(tester, LoginScreen(servidor: servidor), overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      initialAuthStateProvider.overrideWithValue(estado ?? AuthState.unauthenticated()),
    ]);
    return auth;
  }

  Future<void> ingresar(WidgetTester tester, String email, String pass) async {
    await tester.enterText(find.byKey(const ValueKey('login-email')), email);
    await tester.enterText(find.byKey(const ValueKey('login-password')), pass);
    await tester.tap(find.byKey(const ValueKey('login-ingresar')));
    await tester.pump();
  }

  testWidgets('datos incompletos no llaman al servidor', (tester) async {
    final auth = await abrir(tester);
    await ingresar(tester, 'ana', '');
    expect(find.text(l.invalidEmail), findsOneWidget);
    expect(find.text(l.enterPassword), findsOneWidget);
    expect(auth.logins, isEmpty);
  });

  testWidgets('ingreso: correo sin espacios, contraseña tal cual; mientras espera, botón deshabilitado', (tester) async {
    final auth = await abrir(tester);
    auth.gate = Completer();
    await ingresar(tester, ' ana@x.com ', ' clave ');
    expect(auth.logins, [('ana@x.com', ' clave ')]);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('login-ingresar'))).onPressed, isNull);
    auth.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('rechazo: motivo y código', (tester) async {
    final auth = await abrir(tester);
    auth.error = const AuthException('Credenciales inválidas', 401, 'INVALID_CREDENTIALS');
    await ingresar(tester, 'ana@x.com', 'mal');
    await tester.pumpAndSettle();
    expect(find.textContaining('${l.code}: INVALID_CREDENTIALS'), findsOneWidget);
  });

  testWidgets('enter en la contraseña ingresa; el ojo muestra la contraseña', (tester) async {
    final auth = await abrir(tester);
    await tester.enterText(find.byKey(const ValueKey('login-email')), 'ana@x.com');
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'x');
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.logins, hasLength(1));
  });

  testWidgets('sin servidor configurado: aviso y botón deshabilitado', (tester) async {
    await abrir(tester, servidor: '');
    expect(find.text(l.errConfigMissing), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('login-ingresar'))).onPressed, isNull);
  });

  testWidgets('sesión vencida: aviso arriba del formulario', (tester) async {
    await abrir(tester, estado: AuthState.unauthenticated(notice: AuthNotice.sessionExpired));
    expect(find.text(l.sessionExpiredPleaseSignAgain), findsOneWidget);
  });
}
