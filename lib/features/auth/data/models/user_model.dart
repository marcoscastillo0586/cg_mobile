import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.idUsuario,
    required super.nombreUsuario,
    required super.email,
    required super.rol,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idUsuario: json['id_usuario'] is int
          ? json['id_usuario'] as int
          : int.tryParse(json['id_usuario']?.toString() ?? '1') ?? 1,
      nombreUsuario: json['nombre_usuario'] as String? ?? 'Usuario',
      email: json['email'] as String? ?? '',
      rol: json['rol'] as String? ?? 'Usuario',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'nombre_usuario': nombreUsuario,
      'email': email,
      'rol': rol,
    };
  }
}
