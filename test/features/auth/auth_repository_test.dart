// Servidor y almacenamiento SIMULADOS: prueban las reglas del repositorio, no la
// persistencia real del celular (eso se verifica en el dispositivo).
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/auth_interceptor.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import '../../core/auth/fake_auth_server.dart';

class _Setup {
  final FakeAuthServer server;
  final SecureStorageService storage;
  final AuthRepositoryImpl repo;
  int dbDeletes = 0;
  _Setup(this.server, this.storage, this.repo);
}

class _StorageRefresh implements RefreshTokenStorage {
  final SecureStorageService s;
  _StorageRefresh(this.s);
  @override
  Future<String?> read() => s.getRefreshToken();
  @override
  Future<void> write(String token) => s.saveRefreshToken(token);
  @override
  Future<void> delete() => s.deleteRefreshToken();
}

_Setup _build({Map<String, String> initial = const {}}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues(Map.of(initial));
  final storage = SecureStorageService(const FlutterSecureStorage());
  final server = FakeAuthServer();
  final authDio = DioClient.createDio()
    ..options.baseUrl = 'http://api.fake/api/v1'
    ..httpClientAdapter = server;
  final session = SessionManager(authDio: authDio, storage: _StorageRefresh(storage));
  final client = DioClient(adapter: server);
  client.dio.options.baseUrl = 'http://api.fake/api/v1';
  client.dio.interceptors.insert(0, AuthInterceptor(session, client.dio));
  late _Setup setup;
  final repo = AuthRepositoryImpl(AuthRemoteDataSource(session, client), storage, () async => setup.dbDeletes++);
  setup = _Setup(server, storage, repo);
  return setup;
}

void main() {
  test('logout borra la base local y la sesión, y conserva los ajustes', () async {
    final s = _build(initial: {'app_theme_mode': 'dark', 'app_language': 'en', 'is_first_launch_done': 'true'});
    await s.repo.login('ana@test.com', 'clave-larga-123');

    final outcome = await s.repo.logout();

    expect(outcome.revokedOnServer, isTrue);
    expect(s.dbDeletes, 1);
    expect(await s.storage.getRefreshToken(), isNull);
    expect(await s.storage.getUserJson(), isNull);
    expect(await s.storage.getOwnerUserId(), isNull);
    expect(await s.storage.getThemeMode(), 'dark');
    expect(await s.storage.getLanguage(), 'en');
    expect(await s.storage.isFirstLaunchDone(), isTrue);
  });

  test('login de otro usuario borra la base local del anterior', () async {
    final s = _build(initial: {'local_data_owner_user_id': '99'});
    await s.repo.login('ana@test.com', 'clave-larga-123');
    expect(s.dbDeletes, 1);
    expect(await s.storage.getOwnerUserId(), 7);
  });

  test('login del mismo usuario conserva la base local', () async {
    final s = _build(initial: {'local_data_owner_user_id': '7'});
    await s.repo.login('ana@test.com', 'clave-larga-123');
    expect(s.dbDeletes, 0);
  });

  test('sin sesión guardada no hay usuario (no se inventa uno)', () async {
    final s = _build();
    expect(await s.repo.restoreSession(), isNull);
  });

  test('sin red: se usa el último usuario confirmado, marcado sin conexión', () async {
    final s = _build();
    await s.repo.login('ana@test.com', 'clave-larga-123');
    s.server.offline = true;

    final restored = await s.repo.restoreSession();

    expect(restored!.offline, isTrue);
    expect(restored.user.idUsuario, 7);
    expect(restored.connectionError, isA<NetworkException>());
  });

  test('sin red y sin usuario guardado: error de red, no un usuario falso', () async {
    final s = _build(initial: {'auth_refresh_token': 'refresh-x'});
    s.server.offline = true;
    await expectLater(s.repo.restoreSession(), throwsA(isA<NetworkException>()));
  });

  test('con red: renueva la sesión y actualiza el usuario guardado', () async {
    final s = _build();
    await s.repo.login('ana@test.com', 'clave-larga-123');
    final restored = await s.repo.restoreSession();
    expect(restored!.offline, isFalse);
    expect(jsonDecode((await s.storage.getUserJson())!)['email'], 'ana@test.com');
    expect(s.server.refreshCalls, 1);
  });

  test('sesión revocada en el servidor: SessionExpiredException', () async {
    final s = _build();
    await s.repo.login('ana@test.com', 'clave-larga-123');
    s.server.familyRevoked = true;
    await expectLater(s.repo.restoreSession(), throwsA(isA<SessionExpiredException>()));
    expect(await s.storage.getRefreshToken(), isNull);
  });
}
