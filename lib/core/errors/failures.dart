import 'package:equatable/equatable.dart';
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

  /// Validación local con texto traducido: `ValidationFailure.t((l) => l.selectAccount, 'Seleccioná una cuenta')`.
  const ValidationFailure.t(String Function(AppLocalizations l) text, String message) : super(message, null, 'VALIDATION_ERROR', text);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.statusCode, super.code]);
}
