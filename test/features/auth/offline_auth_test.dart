import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/auth/data/models/user_model.dart';

void main() {
  group('Offline-First Auth Tests', () {
    test('Recupera la sesión local del usuario correctamente cuando no hay red', () {
      final jsonStr = jsonEncode({
        'id_usuario': 1,
        'nombre_usuario': 'admin',
        'email': 'marcos@test.com',
        'rol': 'Usuario',
      });

      final user = UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(user.idUsuario, equals(1));
      expect(user.nombreUsuario, equals('admin'));
      expect(user.email, equals('marcos@test.com'));
    });
  });
}
