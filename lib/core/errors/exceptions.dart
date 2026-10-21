class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException(this.message, [this.statusCode]);

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException([this.message = 'No se pudo conectar con el servidor. Revisa tu conexión.']);

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, [this.statusCode = 401]);

  @override
  String toString() => 'AuthException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException([this.message = 'Error al acceder al almacenamiento local']);

  @override
  String toString() => 'CacheException: $message';
}
