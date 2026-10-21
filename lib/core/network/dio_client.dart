import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return DioClient(storageService);
});

class DioClient {
  late final Dio _dio;

  DioClient(SecureStorageService storageService, {void Function()? onUnauthorized}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(storageService, onUnauthorized: onUnauthorized),
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    ]);
  }

  Dio get dio => _dio;



  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  dynamic _handleResponse(Response<dynamic> response) {
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      final bool success = data['success'] as bool? ?? true;
      if (!success) {
        final message = data['message'] as String? ?? 'Ocurrió un error en la solicitud';
        throw ServerException(message, response.statusCode);
      }
      return data['data'] ?? data;
    }
    return data;
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException('Tiempo de espera agotado o sin conexión a internet.');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String message = 'Error del servidor ($statusCode)';
        if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
          message = responseData['message'].toString();
        }
        if (statusCode == 401) {
          return AuthException(message, statusCode);
        }
        return ServerException(message, statusCode);
      case DioExceptionType.cancel:
        return const NetworkException('La solicitud fue cancelada.');
      default:
        return ServerException(error.message ?? 'Error inesperado de comunicación.');
    }
  }
}
