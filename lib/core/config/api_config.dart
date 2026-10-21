/// Configuración de la API, fijada al compilar.
///
/// Se define con `--dart-define=API_BASE_URL=http://<host>:<puerto>/api/v1`.
/// No hay valor por defecto a propósito: sin la variable, la app avisa en el login
/// en lugar de apuntar en silencio a una dirección inventada.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  /// Header que pide al servidor devolver el refresh token en el cuerpo (cliente móvil).
  static const String clientHeader = 'X-Client';
  static const String clientHeaderValue = 'mobile';

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// Base sin barra final; lanza [StateError] si no se configuró al compilar.
  static String get requireBaseUrl {
    if (!isConfigured) {
      throw StateError('API_BASE_URL no está configurada (usar --dart-define).');
    }
    final b = baseUrl.trim();
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }
}
