// Tests con servidor SIMULADO (fake_auth_server.dart): prueban la lógica del cliente
// (mutex de refresh, reintento, expiración, logout), no la red ni la base reales.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/errors/error_messages.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/auth_interceptor.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'fake_auth_server.dart';

class _Setup {
  final FakeAuthServer server;
  final MemoryRefreshStorage storage;
  final SessionManager session;
  final DioClient client;
  _Setup(this.server, this.storage, this.session, this.client);
}

_Setup _build() {
  final server = FakeAuthServer();
  final storage = MemoryRefreshStorage();
  final authDio = DioClient.createDio()
    ..options.baseUrl = 'http://api.fake/api/v1'
    ..httpClientAdapter = server;
  final session = SessionManager(authDio: authDio, storage: storage);
  final client = DioClient(adapter: server);
  client.dio.options.baseUrl = 'http://api.fake/api/v1';
  client.dio.interceptors.insert(0, AuthInterceptor(session, client.dio));
  return _Setup(server, storage, session, client);
}

void main() {
  test('login: access en memoria, refresh guardado, X-Client: mobile enviado', () async {
    final s = _build();
    final result = await s.session.login('ana@test.com', 'clave-larga-123');

    expect(result.user['id'], 7);
    expect(s.session.accessToken, 'access-1');
    // El servidor simulado solo devuelve refreshToken si llegó X-Client: mobile.
    expect(s.storage.value, 'refresh-1');
  });

  test('login incorrecto: AuthException con code INVALID_CREDENTIALS y texto traducido', () async {
    final s = _build();
    Object? error;
    try {
      await s.session.login('ana@test.com', 'mala');
    } catch (e) {
      error = e;
    }
    expect(error, isA<AuthException>());
    expect(ErrorMessages.codeOf(error!), 'INVALID_CREDENTIALS');
    expect(ErrorMessages.describe(error, isEn: false), 'Email o contraseña incorrectos.');
    expect(ErrorMessages.describe(error, isEn: true), 'Wrong email or password.');
    expect(s.storage.value, isNull);
  });

  test('dos llamadas en paralelo con el access vencido producen UN solo refresh', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    s.server.expireAllAccessTokens();

    final results = await Future.wait([s.client.get('/auth/me'), s.client.get('/auth/me')]);

    expect(results.map((r) => (r as Map)['id']), [7, 7]);
    expect(s.server.refreshCalls, 1);
    expect(s.session.refreshRequests, 1);
    expect(s.server.familyRevoked, isFalse);
    expect(s.storage.value, 'refresh-2'); // se guardó el refresh nuevo
  });

  test('cinco llamadas en paralelo con el access vencido: también un solo refresh', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    s.server.expireAllAccessTokens();

    await Future.wait(List.generate(5, (_) => s.client.get('/auth/me')));

    expect(s.server.refreshCalls, 1);
    expect(s.server.meCalls, 10); // 5 con 401 + 5 reintentos
  });

  test('sin mutex el servidor revocaría la familia (control del escenario simulado)', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    final rt = s.storage.value!;
    // Dos refresh directos con el MISMO token, sin pasar por SessionManager.
    final authDio = DioClient.createDio()
      ..options.baseUrl = 'http://api.fake/api/v1'
      ..httpClientAdapter = s.server;
    await authDio.post<dynamic>('/auth/refresh', data: {'refreshToken': rt});
    await expectLater(
      authDio.post<dynamic>('/auth/refresh', data: {'refreshToken': rt}),
      throwsA(anything),
    );
    expect(s.server.familyRevoked, isTrue);
  });

  test('refresh rechazado: SessionExpiredException, aviso emitido y refresh borrado', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    s.server.expireAllAccessTokens();
    s.server.familyRevoked = true; // p. ej. la sesión se revocó en otro dispositivo

    final expired = expectLater(s.session.onExpired, emits(isA<SessionExpiredException>()));
    Object? error;
    try {
      await s.client.get('/auth/me');
    } catch (e) {
      error = e;
    }
    await expired;
    expect(error, isA<SessionExpiredException>());
    expect(ErrorMessages.codeOf(error!), 'INVALID_REFRESH');
    expect(s.storage.value, isNull);
    expect(s.session.accessToken, isNull);
  });

  test('sin red durante el refresh: NetworkException y el refresh token se conserva', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    s.server.offline = true;

    await expectLater(s.session.refresh(), throwsA(isA<NetworkException>()));
    expect(s.storage.value, 'refresh-1');
  });

  test('logout revoca en el servidor y borra los tokens locales', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    final rt = s.storage.value!;

    final outcome = await s.session.logout();

    expect(outcome.revokedOnServer, isTrue);
    expect(s.server.logoutCalls, 1);
    expect(s.server.refreshTokens[rt], isTrue); // revocado
    expect(s.storage.value, isNull);
    expect(s.session.accessToken, isNull);
  });

  test('logout sin red: la sesión local se cierra igual y se informa el error', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    s.server.offline = true;

    final outcome = await s.session.logout();

    expect(outcome.revokedOnServer, isFalse);
    expect(outcome.serverError, isA<NetworkException>());
    expect(s.storage.value, isNull);
  });

  test('error de la API sin sesión: el code llega a la excepción', () async {
    final s = _build();
    await s.session.login('ana@test.com', 'clave-larga-123');
    Object? error;
    try {
      await s.client.get('/no-existe');
    } catch (e) {
      error = e;
    }
    expect(error, isA<ServerException>());
    expect(ErrorMessages.codeOf(error!), 'NOT_FOUND');
  });
}
