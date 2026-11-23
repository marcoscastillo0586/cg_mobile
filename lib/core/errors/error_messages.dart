import 'exceptions.dart';
import 'failures.dart';
import '../../l10n/l10n.dart';

/// Texto para el usuario a partir de un error, traducido según el `code` de la API.
///
/// Códigos tomados de `apps/api` (DomainError) y de docs/sync.md. Si el código no se
/// conoce, se muestra el mensaje del servidor junto con el código, nunca se oculta.
class ErrorMessages {
  ErrorMessages._();

  /// Texto traducido por código de la API.
  static final Map<String, String Function(AppLocalizations l)> _texts = {
    'INVALID_CREDENTIALS': (l) => l.errInvalidCredentials,
    'ACCOUNT_LOCKED': (l) => l.errAccountLocked,
    'RATE_LIMITED': (l) => l.errRateLimited,
    'BUDGET_MIXED_CURRENCY': (l) => l.budgetMixedCurrency,
    'INVALID_REFRESH': (l) => l.errInvalidRefresh,
    'INVALID_TOKEN': (l) => l.errInvalidToken,
    'UNAUTHORIZED': (l) => l.errUnauthorized,
    'NOT_FOUND': (l) => l.errNotFound,
    'DUPLICATE': (l) => l.errDuplicate,
    'EMAIL_TAKEN': (l) => l.errEmailTaken,
    'INSUFFICIENT_FUNDS': (l) => l.errInsufficientFunds,
    'DASHBOARD_FORBIDDEN': (l) => l.errDashboardForbidden,
    'NOT_CREATOR': (l) => l.errNotCreator,
    'OWNER_ONLY': (l) => l.errOwnerOnly,
    'USER_NOT_REGISTERED': (l) => l.errUserNotRegistered,
    'ALREADY_MEMBER': (l) => l.errAlreadyMember,
    'SELF_INVITE': (l) => l.errSelfInvite,
    'OWNER_CANNOT_LEAVE': (l) => l.errOwnerCannotLeave,
    'PRINCIPAL_UNDELETABLE': (l) => l.errPrincipalUndeletable,
    'NOT_PRINCIPAL': (l) => l.errNotPrincipal,
    'INVITATION_CLOSED': (l) => l.errInvitationClosed,
    'RESERVED_CATEGORY': (l) => l.errReservedCategory,
    'SAME_ACCOUNT': (l) => l.errSameAccount,
    'CURRENCY_MISMATCH': (l) => l.errCurrencyMismatch,
    'ACCOUNT_INACTIVE': (l) => l.errAccountInactive,
    'ACCOUNT_HAS_FUNDS': (l) => l.errAccountHasFunds,
    'CURRENCY_LOCKED': (l) => l.errCurrencyLocked,
    'DUPLICATE_NAME': (l) => l.errDuplicateName,
    'INVALID_PERIOD': (l) => l.errInvalidPeriod,
    'LAST_DETAIL': (l) => l.errLastDetail,
    'TRANSFER_EDIT': (l) => l.errTransferEdit,
    'VERSION_CONFLICT': (l) => l.errVersionConflict,
    'CATEGORY_INACTIVE': (l) => l.errCategoryInactive,
    'CATALOG_NOT_SYNCED': (l) => l.errCatalogNotSynced,
    'INTERNAL_ERROR': (l) => l.errInternalError,
    'NOT_AVAILABLE': (l) => l.errNotAvailable,
    'CONFIG_MISSING': (l) => l.errConfigMissing,
    'UNEXPECTED_RESPONSE': (l) => l.errUnexpectedResponse,
    'INSECURE_TRANSPORT': (l) => l.errInsecureTransport,
  };

  static String describe(Object error, AppLocalizations l) {
    if (error is NetworkException || error is NetworkFailure) return l.errNetwork;
    // Validación hecha en el celular: el texto ya es específico (cuenta, disponible, renglón).
    final localized = error is Failure ? error.localized : null;
    if (localized != null) return localized(l);
    return forCode(codeOf(error), _messageOf(error), l);
  }

  static String _messageOf(Object error) => switch (error) {
        ServerException(:final message) => message,
        AuthException(:final message) => message,
        Failure(:final message) => message,
        _ => error.toString(),
      };

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
    final known = _texts[code];
    if (known != null) return known(l);
    if (code == null) return serverMessage;
    return '$serverMessage ($code)';
  }
}
