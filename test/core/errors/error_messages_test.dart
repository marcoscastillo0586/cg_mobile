// Texto que ve el usuario para cada error: traducido por código de la API, nunca oculto si no se conoce.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/error_messages.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/errors/failures.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  const knownCodes = [
    'INVALID_CREDENTIALS', 'ACCOUNT_LOCKED', 'RATE_LIMITED', 'BUDGET_MIXED_CURRENCY', 'INVALID_REFRESH', 'INVALID_TOKEN',
    'UNAUTHORIZED', 'NOT_FOUND', 'DUPLICATE', 'EMAIL_TAKEN', 'INSUFFICIENT_FUNDS', 'DASHBOARD_FORBIDDEN', 'NOT_CREATOR',
    'OWNER_ONLY', 'USER_NOT_REGISTERED', 'ALREADY_MEMBER', 'SELF_INVITE', 'OWNER_CANNOT_LEAVE', 'PRINCIPAL_UNDELETABLE',
    'NOT_PRINCIPAL', 'INVITATION_CLOSED', 'RESERVED_CATEGORY', 'SAME_ACCOUNT', 'CURRENCY_MISMATCH', 'ACCOUNT_INACTIVE',
    'ACCOUNT_HAS_FUNDS', 'CURRENCY_LOCKED', 'DUPLICATE_NAME', 'INVALID_PERIOD', 'LAST_DETAIL', 'TRANSFER_EDIT',
    'VERSION_CONFLICT', 'CATEGORY_INACTIVE', 'CATALOG_NOT_SYNCED', 'INTERNAL_ERROR', 'NOT_AVAILABLE', 'CONFIG_MISSING',
    'UNEXPECTED_RESPONSE', 'INSECURE_TRANSPORT',
  ];

  test('cada código conocido tiene su texto traducido', () {
    for (final l in [es, en]) {
      final texts = [for (final code in knownCodes) ErrorMessages.forCode(code, 'zz-servidor-zz', l)];
      for (final (i, t) in texts.indexed) {
        expect(t, isNot(contains('zz-servidor-zz')), reason: knownCodes[i]);
        expect(t, isNot(contains(knownCodes[i])), reason: knownCodes[i]);
      }
    }
    expect(ErrorMessages.forCode('INSUFFICIENT_FUNDS', 'x', es), es.errInsufficientFunds);
    expect(ErrorMessages.forCode('BUDGET_MIXED_CURRENCY', 'x', en), en.budgetMixedCurrency);
  });

  test('código desconocido: mensaje del servidor con el código; sin código, el mensaje solo', () {
    expect(ErrorMessages.forCode('RARO', 'Algo pasó', es), 'Algo pasó (RARO)');
    expect(ErrorMessages.forCode(null, 'Algo pasó', es), 'Algo pasó');
  });

  test('con código: traducido + (código); desconocido no lo repite; sin código, sólo el motivo; separador', () {
    expect(ErrorMessages.withCode(const ServerException('x', 400, 'INSUFFICIENT_FUNDS'), es), '${es.errInsufficientFunds} (INSUFFICIENT_FUNDS)');
    expect(ErrorMessages.withCode(const ServerException('Algo pasó', 500, 'RARO'), es), 'Algo pasó (RARO)');
    expect(ErrorMessages.withCode(StateError('x'), es), isNot(contains('(')));
    expect(ErrorMessages.withCode(const ServerException('x', 400, 'INSUFFICIENT_FUNDS'), es, sep: '\n'), endsWith('\n(INSUFFICIENT_FUNDS)'));
  });

  test('VALIDATION_ERROR: el mensaje del campo (en español tal cual; en inglés, envuelto)', () {
    expect(ErrorMessages.forCode('VALIDATION_ERROR', 'Fecha inválida', es), 'Fecha inválida');
    expect(ErrorMessages.forCode('VALIDATION_ERROR', 'Fecha inválida', en), en.errInvalidData('Fecha inválida'));
  });

  test('describe según el tipo de error', () {
    expect(ErrorMessages.describe(const NetworkException(), es), es.errNetwork);
    expect(ErrorMessages.describe(const NetworkFailure('x'), es), es.errNetwork);
    expect(ErrorMessages.describe(const ServerException('Sin fondos', 422, 'INSUFFICIENT_FUNDS'), es), es.errInsufficientFunds);
    expect(ErrorMessages.describe(const AuthException('Credenciales', 401, 'INVALID_CREDENTIALS'), es), es.errInvalidCredentials);
    expect(ErrorMessages.describe(const ServerFailure('Duplicado', 409, 'DUPLICATE'), es), es.errDuplicate);
    expect(ErrorMessages.describe(ValidationFailure.t((l) => l.errNetwork), en), en.errNetwork);
    expect(ErrorMessages.describe(const ServerException('Raro', 500, 'X'), es), 'Raro (X)');
    expect(ErrorMessages.describe(StateError('boom'), es), 'Bad state: boom');
  });

  test('codeOf', () {
    expect(ErrorMessages.codeOf(const ServerException('m', 400, 'A')), 'A');
    expect(ErrorMessages.codeOf(const AuthException('m', 401, 'B')), 'B');
    expect(ErrorMessages.codeOf(const ServerFailure('m', 409, 'C')), 'C');
    expect(ErrorMessages.codeOf(const NetworkException()), isNull);
  });
}
