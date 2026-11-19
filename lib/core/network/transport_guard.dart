import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../errors/exceptions.dart';

/// Todo host exige HTTPS. Única excepción: en builds de debug se permite HTTP hacia la PC de la red de
/// casa, para desarrollar contra la API local sin HTTPS (decisión del usuario, 2026-11-19: producción es
/// el VPS con HTTPS y el APK release no debe aceptar HTTP hacia ningún host). Se controla acá porque el
/// cliente HTTP de Dart no aplica el `network_security_config` de Android (verificado: un release
/// llegaba por HTTP).
class TransportGuard extends Interceptor {
  /// Host de la API de desarrollo (PC de casa), con HTTP permitido solo en debug.
  static const devLanHost = '192.168.0.50';

  /// Hosts con HTTP permitido. Vacío en release; los tests agregan sus servidores simulados.
  static final Set<String> httpAllowedHosts = {if (kDebugMode) devLanHost};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (uri.scheme == 'http' && !httpAllowedHosts.contains(uri.host)) {
      handler.reject(DioException(
        requestOptions: options,
        error: const ServerException('Solo se permite HTTPS', null, 'INSECURE_TRANSPORT'),
      ));
      return;
    }
    handler.next(options);
  }
}
