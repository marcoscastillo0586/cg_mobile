import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../errors/exceptions.dart';

/// HTTP sin cifrar solo en debug y solo hacia la PC de desarrollo en la LAN; release y profile
/// exigen HTTPS. Se controla acá porque el cliente HTTP de Dart no aplica el
/// `network_security_config` de Android (verificado en el celular: un release llegaba por HTTP).
class TransportGuard extends Interceptor {
  /// Hosts con HTTP permitido en debug. Los tests agregan sus servidores simulados.
  static final Set<String> debugAllowedHosts = {'192.168.0.50'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    if (uri.scheme == 'http' && !(kDebugMode && debugAllowedHosts.contains(uri.host))) {
      handler.reject(DioException(
        requestOptions: options,
        error: const ServerException('Solo se permite HTTPS', null, 'INSECURE_TRANSPORT'),
      ));
      return;
    }
    handler.next(options);
  }
}
