import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';

class NetworkConfig {
  static const String localServerIp = '192.168.0.50';
  static const String defaultBaseUrl = 'http://192.168.0.50/gastos2.0';

  static const Duration defaultConnectTimeout = Duration(seconds: 15);
  static const Duration defaultReceiveTimeout = Duration(seconds: 45);
  static const Duration defaultSendTimeout = Duration(seconds: 45);

  /// Realiza un ping / health-check rápido a la API en la red local
  static Future<bool> checkServerConnectivity([Dio? dioClient]) async {
    final dio = dioClient ??
        Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );

    try {
      final response = await dio.get<dynamic>('${ApiEndpoints.baseUrl}/api/dashboard/saldos');
      return response.statusCode == 200 || response.statusCode == 401;
    } catch (e) {
      debugPrint('[NETWORK-CONFIG] Health-check falló a ${ApiEndpoints.baseUrl}: $e');
      return false;
    }
  }

  /// Permite cambiar la dirección IP dinámicamente si cambia la red local
  static void setCustomServerIp(String ip, {String port = '', String path = 'gastos2.0'}) {
    final portStr = port.isNotEmpty ? ':$port' : '';
    final pathStr = path.isNotEmpty ? '/$path' : '';
    ApiEndpoints.baseUrl = 'http://$ip$portStr$pathStr';
    debugPrint('[NETWORK-CONFIG] Base URL actualizada a: ${ApiEndpoints.baseUrl}');
  }
}
