import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../errors/exceptions.dart';
import '../auth/session_providers.dart';
import 'auth_interceptor.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  final session = ref.watch(sessionManagerProvider);
  final client = DioClient();
  client.dio.interceptors.insert(0, AuthInterceptor(session, client.dio));
  return client;
});

/// Cliente HTTP de la API `/api/v1`.
///
/// - Las respuestas vienen sin envoltorio: se devuelve el cuerpo tal cual.
/// - Los errores `{statusCode, code, message, details}` se convierten en
///   [ServerException] / [AuthException] con su `code`; los de red en [NetworkException].
class DioClient {
  late final Dio _dio;

  DioClient({List<Interceptor> interceptors = const [], HttpClientAdapter? adapter}) {
    _dio = createDio();
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.addAll([...interceptors, if (kDebugMode) SafeLogInterceptor()]);
  }

  /// Dio con la configuración común (base, timeouts, `X-Client: mobile`), sin interceptores.
  static Dio createDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.isConfigured ? ApiConfig.requireBaseUrl : '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          ApiConfig.clientHeader: ApiConfig.clientHeaderValue,
        },
        responseType: ResponseType.json,
      ),
    );
  }

  Dio get dio => _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: queryParameters, options: options));

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _send(() => _dio.post<dynamic>(path, data: data, queryParameters: queryParameters, options: options));

  Future<dynamic> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _send(() => _dio.put<dynamic>(path, data: data, queryParameters: queryParameters, options: options));

  Future<dynamic> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _send(() => _dio.patch<dynamic>(path, data: data, queryParameters: queryParameters, options: options));

  Future<dynamic> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _send(() => _dio.delete<dynamic>(path, data: data, queryParameters: queryParameters, options: options));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    if (_dio.options.baseUrl.isEmpty) {
      throw const ServerException('API_BASE_URL no configurada', null, 'CONFIG_MISSING');
    }
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Convierte un [DioException] en la excepción de dominio correspondiente.
  static Exception mapDioError(DioException error) {
    final inner = error.error;
    if (inner is AuthException || inner is NetworkException || inner is ServerException) {
      return inner as Exception; // ya mapeada por un interceptor (p. ej. sesión expirada)
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const NetworkException('La solicitud fue cancelada.');
      case DioExceptionType.badResponse:
        return fromResponse(error.response);
      case DioExceptionType.badCertificate:
        return const NetworkException('Certificado del servidor inválido.');
      case DioExceptionType.unknown:
        return NetworkException('Error de comunicación: ${error.message ?? inner}');
    }
  }

  static Exception fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;
    if (body is Map && body['code'] is String) {
      final code = body['code'] as String;
      final message = body['message']?.toString() ?? 'Error del servidor';
      if (status == 401) return AuthException(message, status, code);
      return ServerException(message, status, code, body['details']);
    }
    if (status == 401) return AuthException('No autorizado', status, 'UNAUTHORIZED');
    return ServerException('Respuesta inesperada del servidor (HTTP $status)', status, 'UNEXPECTED_RESPONSE');
  }
}

/// Log de depuración sin datos sensibles: método, ruta y estado. Nunca headers ni cuerpos.
class SafeLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('[HTTP] ${response.requestOptions.method} ${response.requestOptions.path} → ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final body = err.response?.data;
    final code = body is Map ? body['code'] : null;
    debugPrint('[HTTP] ${err.requestOptions.method} ${err.requestOptions.path} → '
        '${err.response?.statusCode ?? err.type.name}${code != null ? ' ($code)' : ''}');
    handler.next(err);
  }
}
