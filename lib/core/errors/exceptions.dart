/// Error devuelto por la API con el formato `{statusCode, code, message, details}`.
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  /// Código estable de la API (p. ej. `INSUFFICIENT_FUNDS`). Es lo que se traduce para el usuario.
  final String? code;
  final Object? details;

  const ServerException(this.message, [this.statusCode, this.code, this.details]);

  @override
  String toString() => 'ServerException($code, HTTP $statusCode): $message';
}

/// Sin conexión, tiempo agotado o servidor inalcanzable.
class NetworkException implements Exception {
  final String message;

  const NetworkException([this.message = 'No se pudo conectar con el servidor. Revisa tu conexión.']);

  @override
  String toString() => 'NetworkException: $message';
}

/// HTTP 401 de la API (credenciales, token o sesión).
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const AuthException(this.message, [this.statusCode = 401, this.code]);

  @override
  String toString() => 'AuthException($code): $message';
}

/// La sesión terminó y no se puede renovar: hay que volver a iniciar sesión.
class SessionExpiredException extends AuthException {
  const SessionExpiredException([String message = 'Sesión expirada. Iniciá sesión nuevamente.'])
      : super(message, 401, 'INVALID_REFRESH');
}

class CacheException implements Exception {
  final String message;

  const CacheException([this.message = 'Error al acceder al almacenamiento local']);

  @override
  String toString() => 'CacheException: $message';
}
