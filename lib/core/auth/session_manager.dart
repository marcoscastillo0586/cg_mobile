import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../errors/exceptions.dart';
import '../network/dio_client.dart';

/// Dónde se guarda el refresh token. En la app es el almacenamiento seguro; en los
/// tests, memoria.
abstract class RefreshTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Resultado del login: tokens ya guardados y el usuario tal como lo devuelve la API.
class LoginResult {
  final Map<String, dynamic> user;
  const LoginResult(this.user);
}

/// Resultado del cierre de sesión en el servidor.
class LogoutOutcome {
  /// null si el servidor revocó el refresh token; si no, el error (p. ej. sin red).
  final Exception? serverError;
  const LogoutOutcome(this.serverError);
  bool get revokedOnServer => serverError == null;
}

/// Maneja los tokens de la sesión.
///
/// - El access token vive **solo en memoria**.
/// - El refresh token rota en cada uso y el servidor revoca toda la familia si se
///   reutiliza uno viejo (`auth.service.ts`). Por eso hay **un solo refresh en vuelo**:
///   las llamadas concurrentes esperan el mismo Future, y el refresh nuevo se guarda
///   antes de entregar el access token.
class SessionManager {
  final Dio _authDio;
  final RefreshTokenStorage _storage;

  String? _accessToken;
  Future<String>? _refreshInFlight;
  final _expiredController = StreamController<SessionExpiredException>.broadcast();

  /// Cantidad de refresh enviados al servidor (diagnóstico y tests).
  int refreshRequests = 0;

  SessionManager({required Dio authDio, required RefreshTokenStorage storage})
      : _authDio = authDio,
        _storage = storage;

  String? get accessToken => _accessToken;

  /// Emite cuando la sesión expira sin posibilidad de renovarse.
  Stream<SessionExpiredException> get onExpired => _expiredController.stream;

  Future<bool> hasSession() async => (await _storage.read()) != null;

  Future<LoginResult> login(String email, String password) async {
    final data = await _post(ApiEndpoints.login, {'email': email, 'password': password});
    await _acceptTokens(data);
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const ServerException('Respuesta de login sin usuario', 200, 'UNEXPECTED_RESPONSE');
    }
    return LoginResult(user);
  }

  /// Renueva el access token. Si ya hay un refresh en curso, devuelve ese mismo.
  Future<String> refresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Llamado tras un 401 de una petición que salió con [usedToken].
  /// Si otra petición ya renovó el token mientras tanto, no se vuelve a renovar.
  Future<String> refreshAfterUnauthorized(String? usedToken) {
    final current = _accessToken;
    if (current != null && current != usedToken) return Future.value(current);
    return refresh();
  }

  Future<String> _doRefresh() async {
    final refreshToken = await _storage.read();
    if (refreshToken == null) {
      throw await _expire();
    }
    refreshRequests++;
    try {
      final data = await _post(ApiEndpoints.refresh, {'refreshToken': refreshToken});
      return await _acceptTokens(data);
    } on AuthException {
      // INVALID_REFRESH: vencido, revocado o reutilizado. No hay forma de renovar.
      throw await _expire();
    }
  }

  /// Revoca el refresh token en el servidor y borra los tokens locales.
  /// Los tokens locales se borran siempre, aunque el servidor no responda.
  Future<LogoutOutcome> logout() async {
    Exception? serverError;
    final refreshToken = await _storage.read();
    if (refreshToken != null) {
      try {
        await _post(ApiEndpoints.logout, {'refreshToken': refreshToken});
      } on Exception catch (e) {
        serverError = e;
        debugPrint('[AUTH] No se pudo revocar la sesión en el servidor: $e');
      }
    }
    _accessToken = null;
    await _storage.delete();
    return LogoutOutcome(serverError);
  }

  Future<String> _acceptTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || refresh is! String) {
      // Sin refresh en el cuerpo: falta el header X-Client: mobile o cambió la API.
      throw const ServerException('La respuesta no trae los tokens esperados', 200, 'UNEXPECTED_RESPONSE');
    }
    await _storage.write(refresh); // primero persistir el refresh nuevo
    _accessToken = access;
    return access;
  }

  Future<SessionExpiredException> _expire() async {
    _accessToken = null;
    await _storage.delete();
    const e = SessionExpiredException();
    _expiredController.add(e);
    return e;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (_authDio.options.baseUrl.isEmpty) {
      throw const ServerException('API_BASE_URL no configurada', null, 'CONFIG_MISSING');
    }
    try {
      final response = await _authDio.post<dynamic>(path, data: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (response.statusCode == 204) return const {};
      throw ServerException('Respuesta inesperada del servidor', response.statusCode, 'UNEXPECTED_RESPONSE');
    } on DioException catch (e) {
      throw DioClient.mapDioError(e);
    }
  }

  void dispose() => _expiredController.close();
}
