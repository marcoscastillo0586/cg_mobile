import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Locale;
import '../../l10n/l10n.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  /// Código de la API (si lo hubo), para traducirlo con ErrorMessages.
  final String? code;

  /// Texto traducido para el usuario (validaciones hechas en el celular); [message] queda para los logs.
  final String Function(AppLocalizations l)? localized;

  const Failure(this.message, [this.statusCode, this.code, this.localized]);

  @override
  List<Object?> get props => [message, statusCode, code];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.statusCode, super.code]);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.statusCode, super.code]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.statusCode, super.code]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.statusCode, super.code]);

  /// Validación hecha en el celular con texto traducido: `ValidationFailure.t((l) => l.selectAnAccount)`.
  /// [message] queda en español (logs y tests).
  ValidationFailure.t(String Function(AppLocalizations l) text, [String code = 'VALIDATION_ERROR'])
      : super(text(_es), null, code, text);

  static final _es = lookupAppLocalizations(const Locale('es'));
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.statusCode, super.code]);
}
