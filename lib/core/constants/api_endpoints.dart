import '../config/api_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Base de la API nueva (`/api/v1`), fijada al compilar con `--dart-define=API_BASE_URL`.
  static String get baseUrl => ApiConfig.baseUrl;

  // Auth (API nueva; rutas relativas a la base del cliente)
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // ---------------------------------------------------------------------------
  // CONTRATO PHP VIEJO: solo lo que todavía leen los formularios de egreso, ingreso y
  // transferencia (responde 404 contra /api/v1). Se reemplaza en la etapa 5.
  // ---------------------------------------------------------------------------
  static String get formularioEgreso => '$baseUrl/api/egresos/formulario_data';
  static String get sugerirCategoria => '$baseUrl/api/egresos/sugerir_categoria';
}
