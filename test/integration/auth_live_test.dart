// Prueba EN VIVO contra una API real (red y base reales). Se saltea si faltan las variables.
//
//   CG_LIVE_API      p. ej. http://192.168.0.50:3000/api/v1  (servidor de PRUEBAS, nunca el real)
//   CG_LIVE_EMAIL    usuario de prueba
//   CG_LIVE_PASSWORD su contraseña (no se imprime)
//   CG_LIVE_TTL      segundos de vida del access token con que se levantó el servidor
//
// Usa el mismo código que la app (SessionManager + DioClient + AuthInterceptor).
// Corre en la PC: prueba red y servidor reales, NO el celular.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';
import 'package:gastos_mobile/core/errors/error_messages.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/auth_interceptor.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import '../core/auth/fake_auth_server.dart' show MemoryRefreshStorage;

void main() {
  final env = Platform.environment;
  final api = env['CG_LIVE_API'];
  final email = env['CG_LIVE_EMAIL'];
  final password = env['CG_LIVE_PASSWORD'];
  final ttl = int.tryParse(env['CG_LIVE_TTL'] ?? '');
  final skip = (api == null || email == null || password == null || ttl == null)
      ? 'Faltan CG_LIVE_API / CG_LIVE_EMAIL / CG_LIVE_PASSWORD / CG_LIVE_TTL'
      : null;

  late MemoryRefreshStorage storage;
  late SessionManager session;
  late DioClient client;

  setUp(() {
    storage = MemoryRefreshStorage();
    final authDio = DioClient.createDio()..options.baseUrl = api ?? '';
    session = SessionManager(authDio: authDio, storage: storage);
    client = DioClient();
    client.dio.options.baseUrl = api ?? '';
    client.dio.interceptors.insert(0, AuthInterceptor(session, client.dio));
  });

  test('login incorrecto devuelve INVALID_CREDENTIALS', skip: skip, () async {
    Object? error;
    try {
      await session.login(email!, '${password!}-incorrecta');
    } catch (e) {
      error = e;
    }
    print('[LIVE] login incorrecto → ${ErrorMessages.codeOf(error!)} | "${ErrorMessages.describe(error, isEn: false)}"');
    expect(ErrorMessages.codeOf(error), 'INVALID_CREDENTIALS');
  });

  test('access vencido + 2 llamadas paralelas = 1 refresh; logout revoca', skip: skip, () async {
    final login = await session.login(email!, password!);
    print('[LIVE] login OK: usuario id=${login.user['id']} | refresh recibido en el cuerpo: ${storage.value != null}');
    expect(storage.value, isNotNull, reason: 'sin X-Client: mobile el servidor no devuelve el refresh');
    final firstRefresh = storage.value!;

    print('[LIVE] esperando ${ttl! + 2} s a que venza el access token…');
    await Future<void>.delayed(Duration(seconds: ttl + 2));

    final results = await Future.wait([client.get('/auth/me'), client.get('/auth/me')]);
    print('[LIVE] 2 GET /auth/me en paralelo → ids ${results.map((r) => (r as Map)['id']).toList()} | '
        'refresh enviados: ${session.refreshRequests}');
    expect(session.refreshRequests, 1);
    expect(storage.value, isNot(firstRefresh), reason: 'se guardó el refresh rotado');

    final outcome = await session.logout();
    print('[LIVE] logout → revocado en el servidor: ${outcome.revokedOnServer}');
    expect(outcome.revokedOnServer, isTrue);

    // El refresh vigente antes del logout ya no sirve.
    final raw = DioClient.createDio()..options.baseUrl = api!;
    Object? after;
    try {
      await raw.post<dynamic>('/auth/refresh', data: {'refreshToken': firstRefresh});
    } on DioException catch (e) {
      after = DioClient.mapDioError(e);
    }
    print('[LIVE] refresh con un token ya usado → ${ErrorMessages.codeOf(after!)}');
    expect(after, isA<AuthException>());
    expect(ErrorMessages.codeOf(after), 'INVALID_REFRESH');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
