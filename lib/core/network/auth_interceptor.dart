import 'package:dio/dio.dart';
import '../auth/session_manager.dart';
import '../constants/api_endpoints.dart';

/// Agrega el access token y, ante un 401, renueva la sesión una sola vez y reintenta.
///
/// - Sin access token en memoria pero con sesión guardada (p. ej. al abrir la app),
///   renueva antes de enviar.
/// - Un 401 dispara `refreshAfterUnauthorized`: si otra petición ya renovó, reutiliza
///   ese token; si no, se suma al único refresh en vuelo.
/// - Si la sesión no se puede renovar, el error que llega es [SessionExpiredException].
class AuthInterceptor extends Interceptor {
  final SessionManager _session;
  final Dio _dio;

  static const _kToken = 'auth.usedToken';
  static const _kRetried = 'auth.retried';

  AuthInterceptor(this._session, this._dio);

  static bool _isAuthEndpoint(String path) =>
      path.endsWith(ApiEndpoints.login) || path.endsWith(ApiEndpoints.refresh) || path.endsWith(ApiEndpoints.logout);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isAuthEndpoint(options.path)) return handler.next(options);

    var token = _session.accessToken;
    if (token == null) {
      try {
        if (await _session.hasSession()) token = await _session.refresh();
      } catch (e) {
        return handler.reject(DioException(requestOptions: options, error: e, type: DioExceptionType.unknown));
      }
    }
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    options.extra[_kToken] = token;
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    if (!unauthorized || options.extra[_kRetried] == true || _isAuthEndpoint(options.path)) {
      return handler.next(err);
    }
    try {
      final newToken = await _session.refreshAfterUnauthorized(options.extra[_kToken] as String?);
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra[_kToken] = newToken;
      options.extra[_kRetried] = true;
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (e) {
      handler.next(DioException(
        requestOptions: options,
        response: err.response,
        error: e,
        type: DioExceptionType.unknown,
      ));
    }
  }
}
