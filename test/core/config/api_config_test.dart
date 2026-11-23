// Dirección de la API fijada al compilar: en los tests no se define, y la app lo avisa en vez de inventar una.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/config/api_config.dart';

void main() {
  test('sin API_BASE_URL: no está configurada y pedirla falla con un mensaje claro', () {
    expect(ApiConfig.isConfigured, isFalse);
    expect(() => ApiConfig.requireBaseUrl, throwsA(isA<StateError>().having((e) => e.message, 'message', contains('--dart-define'))));
  });

  test('la base se usa sin barra final ni espacios', () {
    expect(ApiConfig.withoutTrailingSlash(' https://x.com/api/v1/ '), 'https://x.com/api/v1');
    expect(ApiConfig.withoutTrailingSlash('https://x.com/api/v1'), 'https://x.com/api/v1');
  });
}
