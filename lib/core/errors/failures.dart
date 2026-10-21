import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  /// Código de la API (si lo hubo), para traducirlo con ErrorMessages.
  final String? code;

  const Failure(this.message, [this.statusCode, this.code]);

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
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.statusCode, super.code]);
}
