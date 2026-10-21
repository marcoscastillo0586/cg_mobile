import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int idUsuario;
  final String nombreUsuario;
  final String email;
  final String rol;

  const UserEntity({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.email,
    required this.rol,
  });

  @override
  List<Object?> get props => [idUsuario, nombreUsuario, email, rol];
}
