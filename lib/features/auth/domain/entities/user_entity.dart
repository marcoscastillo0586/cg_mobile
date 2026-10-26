import 'package:equatable/equatable.dart';

/// Usuario autenticado (UserDto de la API: id, name, email).
class UserEntity extends Equatable {
  final int idUsuario;
  final String nombreUsuario;
  final String email;

  /// Moneda principal ('ARS' | 'USD'); null si todavía no la eligió.
  final String? monedaPrincipal;

  const UserEntity({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.email,
    this.monedaPrincipal,
  });

  @override
  List<Object?> get props => [idUsuario, nombreUsuario, email, monedaPrincipal];
}
