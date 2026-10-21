import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/constants/api_endpoints.dart';
import 'package:gastos_mobile/core/network/network_config.dart';

void main() {
  group('NetworkConfig & Local IP Server Tests', () {
    test('Configura la dirección IP local 192.168.0.50 correctamente', () {
      expect(NetworkConfig.localServerIp, equals('192.168.0.50'));
      expect(NetworkConfig.defaultBaseUrl, contains('192.168.0.50'));

      NetworkConfig.setCustomServerIp('192.168.0.50', path: 'gastos2.0');
      expect(ApiEndpoints.baseUrl, equals('http://192.168.0.50/gastos2.0'));
      expect(ApiEndpoints.login, equals('http://192.168.0.50/gastos2.0/api/auth/login'));
      expect(ApiEndpoints.crearEgreso, equals('http://192.168.0.50/gastos2.0/api/egresos/crear'));
    });
  });
}
