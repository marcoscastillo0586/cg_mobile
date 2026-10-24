import 'exceptions.dart';
import 'failures.dart';
import '../../l10n/l10n.dart';

/// Texto para el usuario a partir de un error, traducido según el `code` de la API.
///
/// Códigos tomados de `apps/api` (DomainError) y de docs/sync.md. Si el código no se
/// conoce, se muestra el mensaje del servidor junto con el código, nunca se oculta.
class ErrorMessages {
  ErrorMessages._();

  static String? _byCode(String code, AppLocalizations l) => switch (code) {
        'INVALID_CREDENTIALS' => l.errInvalidCredentials,
        'ACCOUNT_LOCKED' => l.errAccountLocked,
        'RATE_LIMITED' => l.errRateLimited,
        'INVALID_REFRESH' => l.errInvalidRefresh,
        'INVALID_TOKEN' => l.errInvalidToken,
        'UNAUTHORIZED' => l.errUnauthorized,
        'NOT_FOUND' => l.errNotFound,
        'DUPLICATE' => l.errDuplicate,
        'EMAIL_TAKEN' => l.errEmailTaken,
        'INSUFFICIENT_FUNDS' => l.errInsufficientFunds,
        'RESERVED_CATEGORY' => l.errReservedCategory,
        'SAME_ACCOUNT' => l.errSameAccount,
        'CURRENCY_MISMATCH' => l.errCurrencyMismatch,
        'ACCOUNT_INACTIVE' => l.errAccountInactive,
        'ACCOUNT_HAS_FUNDS' => l.errAccountHasFunds,
        'CURRENCY_LOCKED' => l.errCurrencyLocked,
        'DUPLICATE_NAME' => l.errDuplicateName,
        'INVALID_PERIOD' => l.errInvalidPeriod,
        'LAST_DETAIL' => l.errLastDetail,
        'TRANSFER_EDIT' => l.errTransferEdit,
        'VERSION_CONFLICT' => l.errVersionConflict,
        'CATEGORY_INACTIVE' => l.errCategoryInactive,
        'CATALOG_NOT_SYNCED' => l.errCatalogNotSynced,
        'INTERNAL_ERROR' => l.errInternalError,
        'NOT_AVAILABLE' => l.errNotAvailable,
        'CONFIG_MISSING' => l.errConfigMissing,
        'UNEXPECTED_RESPONSE' => l.errUnexpectedResponse,
        'INSECURE_TRANSPORT' => l.errInsecureTransport,
        _ => null,
      };

  static String describe(Object error, AppLocalizations l) {
    if (error is NetworkException || error is NetworkFailure) return l.errNetwork;
    String? code;
    String message = error.toString();
    if (error is ServerException) {
      code = error.code;
      message = error.message;
    } else if (error is AuthException) {
      code = error.code;
      message = error.message;
    } else if (error is Failure) {
      // Validación hecha en el celular: el texto ya es específico (cuenta, disponible, renglón).
      final localized = error.localized;
      if (localized != null) return localized(l);
      code = error.code;
      message = error.message;
    }
    return forCode(code, message, l);
  }

  /// Código de la API del error, si lo tiene.
  static String? codeOf(Object error) {
    if (error is ServerException) return error.code;
    if (error is AuthException) return error.code;
    if (error is Failure) return error.code;
    return null;
  }

  static String forCode(String? code, String serverMessage, AppLocalizations l) {
    // VALIDATION_ERROR trae un mensaje específico del campo (del servidor, en español).
    if (code == 'VALIDATION_ERROR') return l.localeName == 'es' ? serverMessage : l.errInvalidData(serverMessage);
    final known = code == null ? null : _byCode(code, l);
    if (known != null) return known;
    if (code == null) return serverMessage;
    return '$serverMessage ($code)';
  }
}
