import 'exceptions.dart';
import 'failures.dart';

/// Texto para el usuario a partir de un error, traducido según el `code` de la API.
///
/// Códigos tomados de `apps/api` (DomainError) y de docs/sync.md. Si el código no se
/// conoce, se muestra el mensaje del servidor junto con el código, nunca se oculta.
class ErrorMessages {
  ErrorMessages._();

  static const Map<String, (String es, String en)> _byCode = {
    'INVALID_CREDENTIALS': ('Email o contraseña incorrectos.', 'Wrong email or password.'),
    'ACCOUNT_LOCKED': (
      'Demasiados intentos fallidos. Probá de nuevo en 15 minutos.',
      'Too many failed attempts. Try again in 15 minutes.'
    ),
    'RATE_LIMITED': ('Demasiadas solicitudes. Esperá un momento.', 'Too many requests. Please wait a moment.'),
    'INVALID_REFRESH': ('Tu sesión expiró. Iniciá sesión nuevamente.', 'Your session expired. Please sign in again.'),
    'INVALID_TOKEN': ('Tu sesión expiró. Iniciá sesión nuevamente.', 'Your session expired. Please sign in again.'),
    'UNAUTHORIZED': ('Tenés que iniciar sesión.', 'You need to sign in.'),
    'NOT_FOUND': (
      'El servidor no tiene esta función o el dato no existe.',
      'The server does not have this feature or the item does not exist.'
    ),
    'DUPLICATE': ('Ya existe un registro con esos datos.', 'A record with that data already exists.'),
    'EMAIL_TAKEN': ('Ya existe una cuenta con ese email.', 'An account with that email already exists.'),
    'INSUFFICIENT_FUNDS': (
      'No dispone del saldo a transferir. Realizá un ingreso en la cuenta de origen.',
      'Not enough balance to transfer. Record an income in the source account first.'
    ),
    'RESERVED_CATEGORY': ('Esa categoría está reservada por el sistema.', 'That category is reserved by the system.'),
    'SAME_ACCOUNT': ('La cuenta de origen y la de destino no pueden ser iguales.', 'Source and destination accounts must differ.'),
    'CURRENCY_MISMATCH': (
      'No se puede transferir entre cuentas de distinta moneda.',
      'Cannot transfer between accounts in different currencies.'
    ),
    'ACCOUNT_INACTIVE': ('La cuenta está inactiva.', 'The account is inactive.'),
    'CATEGORY_INACTIVE': ('La categoría está inactiva.', 'The category is inactive.'),
    'CATALOG_NOT_SYNCED': (
      'Faltan datos del servidor en el celular: sincronizá con conexión.',
      'Server data is missing on this phone: sync while online.'
    ),
    'INTERNAL_ERROR': ('Error interno del servidor.', 'Internal server error.'),
    'NOT_AVAILABLE': ('Función no disponible por ahora.', 'Feature not available for now.'),
    'CONFIG_MISSING': (
      'La app no tiene configurada la dirección del servidor (API_BASE_URL).',
      'The app has no server address configured (API_BASE_URL).'
    ),
    'UNEXPECTED_RESPONSE': ('El servidor respondió algo inesperado.', 'Unexpected response from the server.'),
  };

  static String describe(Object error, {required bool isEn}) {
    if (error is NetworkException) {
      return isEn ? 'Cannot reach the server. Check your connection.' : 'No se pudo conectar con el servidor. Revisá tu conexión.';
    }
    if (error is NetworkFailure) {
      return isEn ? 'Cannot reach the server. Check your connection.' : 'No se pudo conectar con el servidor. Revisá tu conexión.';
    }
    String? code;
    String message = error.toString();
    if (error is ServerException) {
      code = error.code;
      message = error.message;
    } else if (error is AuthException) {
      code = error.code;
      message = error.message;
    } else if (error is Failure) {
      code = error.code;
      message = error.message;
      // Validación hecha en el celular: el mensaje ya es específico (cuenta, disponible, renglón).
      if (error is ValidationFailure && !isEn) return message;
    }
    return forCode(code, message, isEn: isEn);
  }

  /// Código de la API del error, si lo tiene.
  static String? codeOf(Object error) {
    if (error is ServerException) return error.code;
    if (error is AuthException) return error.code;
    if (error is Failure) return error.code;
    return null;
  }

  static String forCode(String? code, String serverMessage, {required bool isEn}) {
    // VALIDATION_ERROR trae un mensaje específico del campo: se muestra tal cual.
    if (code == 'VALIDATION_ERROR') {
      return isEn ? 'Invalid data: $serverMessage' : serverMessage;
    }
    final known = code == null ? null : _byCode[code];
    if (known != null) return isEn ? known.$2 : known.$1;
    if (code == null) return serverMessage;
    return '$serverMessage ($code)';
  }
}
