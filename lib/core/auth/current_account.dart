/// Cuenta con sesión iniciada en este celular. Separa sus datos locales: cada cuenta tiene sus propias
/// bases ([LocalDatabase]), copias guardadas, valores pendientes y moneda principal. La fija
/// [SessionScope] al iniciar sesión y la quita al cerrarla (los datos quedan en el celular).
class CurrentAccount {
  CurrentAccount._();

  static int? id;

  /// Clave de almacenamiento propia de la cuenta conectada (p. ej. `dashboards_cache_u7`).
  static String key(String base) => '${base}_u${requireId()}';

  static int requireId() {
    final user = id;
    if (user == null) throw StateError('No hay una cuenta con sesión iniciada: no hay datos locales que usar.');
    return user;
  }
}
