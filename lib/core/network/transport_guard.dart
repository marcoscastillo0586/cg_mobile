import 'package:dio/dio.dart';
import '../errors/exceptions.dart';

/// HTTP sin cifrar solo hacia la PC de la red de casa (decisión del usuario, 2026-10-24: la API real
/// corre ahí sin HTTPS); cualquier otro host exige HTTPS. Se controla acá porque el cliente HTTP de
/// Dart no aplica el `network_security_config` de Android (verificado: un release llegaba por HTTP).
class TransportGuard extends Interceptor {
  /// Hosts con HTTP permitido. Los tests agregan sus servidores simulados.
  static final Set<String> httpAllowedHosts = {'192.168.0.50'};

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
