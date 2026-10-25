import 'package:flutter/foundation.dart';
import '../errors/exceptions.dart';

/// Si el servidor respondió en la última petición. Lo actualiza [DioClient] con cada respuesta.
///
/// "Sin conexión": sin red, servidor inalcanzable, tiempo agotado, error de conexión, 5xx y
/// `TEMPORARY_ERROR`. En ese estado la app usa lo guardado en el celular sin avisar.
class ServerReachability {
  ServerReachability._();

  /// Mientras dure, no se vuelve a esperar al servidor antes de mostrar una pantalla: se
  /// reintenta en el ciclo automático (cada 30 s), al volver a la app o con ↻.
  static const window = Duration(seconds: 30);

  static final offline = ValueNotifier<bool>(false);
  static DateTime? _lastFailure;

  static bool isOfflineError(Object e) =>
      e is NetworkException || (e is ServerException && ((e.statusCode ?? 0) >= 500 || e.code == 'TEMPORARY_ERROR'));

  static void markOnline() {
    _lastFailure = null;
    offline.value = false;
  }

  static void markOffline() {
    _lastFailure = DateTime.now();
    offline.value = true;
  }

  /// La última petición falló por falta de conexión hace menos de [window].
  static bool get recentlyOffline {
    final last = _lastFailure;
    return offline.value && last != null && DateTime.now().difference(last) < window;
  }
}
