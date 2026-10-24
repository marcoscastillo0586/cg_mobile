// Cierre de sesión sin cerrar la app: ningún provider conserva datos del usuario anterior.
// Repositorio de auth SIMULADO; el borrado real de la base se prueba en el celular.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';

class _FakeAuth implements AuthRepository {
  // ignore: close_sinks — se cierra con addTearDown en cada test.
  final expired = StreamController<Object>.broadcast();
  int restores = 0;
  Exception? logoutError;

  @override
  Future<UserEntity> login(String email, String password) async =>
      UserEntity(idUsuario: email == 'a@x' ? 1 : 5, nombreUsuario: email, email: email);

  @override
  Future<RestoredSession?> restoreSession() async {
    restores++;
    return const RestoredSession(UserEntity(idUsuario: 1, nombreUsuario: 'a', email: 'a@x'));
  }

  @override
  Future<LogoutOutcome> logout() async => LogoutOutcome(logoutError);

  @override
  Stream<Object> get onSessionExpired => expired.stream;
}

/// Datos del usuario en memoria (como los notifiers de saldos o la base local abierta).
final _userData = StateProvider<String?>((ref) => null);
var _databasesOpened = 0;
final _database = Provider<int>((ref) => ++_databasesOpened);

void main() {
  late _FakeAuth auth;
  late ProviderContainer Function() container;

  Future<void> pump(WidgetTester tester) async {
    auth = _FakeAuth();
    addTearDown(auth.expired.close);
    await tester.pumpWidget(SessionScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: Consumer(builder: (context, ref, _) {
        final s = ref.watch(authNotifierProvider);
        ref.watch(_database);
        return Text('${s.status.name} ${s.user?.idUsuario} ${ref.watch(_userData)}', textDirection: TextDirection.ltr);
      }),
    ));
    container = () => ProviderScope.containerOf(tester.element(find.byType(Text)));
    await tester.pump();
  }

  testWidgets('al cerrar sesión se descarta todo el estado en memoria y la base abierta', (tester) async {
    _databasesOpened = 0;
    await pump(tester);
    expect(find.text('authenticated 1 null'), findsOneWidget);
    container().read(_userData.notifier).state = 'saldos del usuario 1';
    await tester.pump();
    expect(find.text('authenticated 1 saldos del usuario 1'), findsOneWidget);
    final first = container();

    auth.logoutError = Exception('sin red');
    await container().read(authNotifierProvider.notifier).logout();
    await tester.pump();
    await tester.pump();

    expect(container(), isNot(same(first)), reason: 'contenedor nuevo');
    expect(find.text('unauthenticated null null'), findsOneWidget);
    final s = container().read(authNotifierProvider);
    expect(s.notice, AuthNotice.logoutNotRevoked, reason: 'el aviso de logout sin red no se pierde');
    expect(auth.restores, 1, reason: 'el contenedor nuevo no vuelve a consultar la sesión guardada');
    expect(_databasesOpened, 2, reason: 'la base se vuelve a abrir en el contenedor nuevo');

    await container().read(authNotifierProvider.notifier).login('b@x', 'x');
    await tester.pump();
    expect(find.text('authenticated 5 null'), findsOneWidget);
  });

  testWidgets('sesión expirada durante el uso: también se descarta el estado', (tester) async {
    await pump(tester);
    container().read(_userData.notifier).state = 'datos';
    final first = container();
    auth.expired.add(Object());
    await tester.pump();
    await tester.pump();
    expect(container(), isNot(same(first)));
    expect(container().read(authNotifierProvider).notice, AuthNotice.sessionExpired);
    expect(container().read(_userData), isNull);
  });
}
