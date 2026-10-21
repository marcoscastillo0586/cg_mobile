import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.idUsuario,
    required super.nombreUsuario,
    required super.email,
  });

  /// Desde `UserDto` de la API (`{id, name, email, active, createdAt}`) o desde la copia
  /// guardada con [toJson]. Sin `id` válido es un error: no se inventa un usuario.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const ServerException('Usuario sin id en la respuesta', null, 'UNEXPECTED_RESPONSE');
    }
    return UserModel(
      idUsuario: id,
      nombreUsuario: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': idUsuario, 'name': nombreUsuario, 'email': email};
}
