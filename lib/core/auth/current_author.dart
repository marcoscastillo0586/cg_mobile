import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Quién carga en el celular: queda como autor de lo creado sin conexión (dashboards compartidos)
/// hasta que la descarga trae el dato del servidor.
class LocalAuthor {
  final int id;
  final String name;
  const LocalAuthor(this.id, this.name);
}

final currentAuthorProvider = Provider<LocalAuthor?>((ref) {
  final user = ref.watch(authNotifierProvider.select((s) => s.user));
  return user == null ? null : LocalAuthor(user.idUsuario, user.nombreUsuario);
});
