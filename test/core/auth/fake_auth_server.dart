import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gastos_mobile/core/auth/session_manager.dart';

/// Servidor de auth SIMULADO en memoria. Imita las reglas de `apps/api/src/auth/auth.service.ts`:
/// - login devuelve refreshToken en el cuerpo solo con `X-Client: mobile`;
/// - el refresh rota el token; reutilizar uno ya rotado revoca toda la familia;
/// - las rutas protegidas responden 401 INVALID_TOKEN con un access vencido o desconocido.
/// No reemplaza la prueba contra la API real: no hay red ni base de datos.
class FakeAuthServer implements HttpClientAdapter {
  final String email;
  final String password;
  final Duration latency;

  int _seq = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int meCalls = 0;
  final Set<String> validAccess = {};
  final Map<String, bool> refreshTokens = {}; // token → revocado
  bool familyRevoked = false;
  bool offline = false;

  FakeAuthServer({this.email = 'ana@test.com', this.password = 'clave-larga-123', this.latency = const Duration(milliseconds: 30)});

  /// Simula que todos los access tokens emitidos vencieron.
  void expireAllAccessTokens() => validAccess.clear();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline (simulado)');
    }
    await Future<void>.delayed(latency);
    final body = options.data is Map ? options.data as Map : const <String, dynamic>{};
    final mobile = options.headers['X-Client'] == 'mobile';
    switch (options.path) {
      case '/auth/login':
        if (body['email'] != email || body['password'] != password) {
          return _json(401, {'statusCode': 401, 'code': 'INVALID_CREDENTIALS', 'message': 'Credenciales inválidas'});
        }
        return _json(200, _issue(mobile));
      case '/auth/refresh':
        refreshCalls++;
        final rt = body['refreshToken'] as String?;
        final revoked = rt == null ? null : refreshTokens[rt];
        if (revoked == null || revoked || familyRevoked) {
          if (revoked == true) familyRevoked = true; // reutilización → se revoca la familia
          return _json(401, {'statusCode': 401, 'code': 'INVALID_REFRESH', 'message': 'Sesión expirada.'});
        }
        refreshTokens[rt!] = true;
        return _json(200, _issue(mobile));
      case '/auth/logout':
        logoutCalls++;
        final rt = body['refreshToken'] as String?;
        if (rt != null && refreshTokens.containsKey(rt)) refreshTokens[rt] = true;
        return ResponseBody.fromString('', 204);
      case '/auth/me':
        meCalls++;
        final auth = options.headers['Authorization'] as String?;
        final token = auth?.replaceFirst('Bearer ', '');
        if (token == null || !validAccess.contains(token)) {
          return _json(401, {'statusCode': 401, 'code': 'INVALID_TOKEN', 'message': 'Token inválido o expirado'});
        }
        return _json(200, {'id': 7, 'name': 'Ana', 'email': email, 'active': true, 'createdAt': '2026-10-01T00:00:00Z'});
      default:
        return _json(404, {'statusCode': 404, 'code': 'NOT_FOUND', 'message': 'Not Found'});
    }
  }

  Map<String, dynamic> _issue(bool mobile) {
    _seq++;
    final access = 'access-$_seq';
    final refresh = 'refresh-$_seq';
    validAccess.add(access);
    refreshTokens[refresh] = false;
    return {
      'accessToken': access,
      if (mobile) 'refreshToken': refresh,
      'user': {'id': 7, 'name': 'Ana', 'email': email, 'active': true, 'createdAt': '2026-10-01T00:00:00Z'},
    };
  }

  ResponseBody _json(int status, Map<String, dynamic> data) => ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}

/// Refresh token en memoria (en la app es el almacenamiento seguro).
class MemoryRefreshStorage implements RefreshTokenStorage {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async {
    writes++;
    value = token;
  }

  @override
  Future<void> delete() async => value = null;
}
