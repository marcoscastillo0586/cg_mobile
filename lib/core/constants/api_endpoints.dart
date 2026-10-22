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
}
