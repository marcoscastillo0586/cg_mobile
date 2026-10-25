import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dashboard elegido en este celular. `null` = el principal del usuario: su base local es
/// `cg_local.db` y los pedidos van sin X-Dashboard-Id (el servidor usa el principal).
///
/// Vive fuera del contenedor de providers: al cambiarlo, [SessionScope] descarta el contenedor entero
/// y el nuevo abre la base local de ese dashboard, así los datos de dos dashboards nunca se mezclan
/// en memoria ni en disco (docs/dashboards.md de CG).
class CurrentDashboard {
  CurrentDashboard._();

  static final id = ValueNotifier<int?>(null);

  /// Aviso para mostrar una vez (código; la pantalla lo traduce). Ver [accessLost].
  static final notice = ValueNotifier<String?>(null);

  /// Se perdió el acceso al dashboard elegido y se volvió al principal.
  static const accessLost = 'ACCESS_LOST';

  static const _key = 'current_dashboard';
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  /// Recupera la elección guardada (`usuario:dashboard`; dashboard vacío = principal) y la aplica.
  /// Devuelve el usuario al que pertenece, para descartarla si inicia sesión otro.
  static Future<int?> restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final parts = raw.split(':');
      final userId = int.tryParse(parts.first);
      id.value = parts.length > 1 ? int.tryParse(parts[1]) : null;
      return userId;
    } catch (e) {
      debugPrint('[DASHBOARD] No se pudo leer el dashboard elegido; se usa el principal: $e');
      id.value = null;
      return null;
    }
  }

  /// Guarda la elección (null = principal). No cambia [id]: eso lo hace quien cambia de dashboard.
  static Future<void> save(int userId, int? dashboardId) =>
      _storage.write(key: _key, value: '$userId:${dashboardId ?? ''}');

  /// Borra la elección guardada (cierre de sesión). [id] lo vuelve a null [SessionScope].
  static Future<void> forget() => _storage.delete(key: _key);
}
