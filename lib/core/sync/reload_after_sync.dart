import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_controller.dart';

/// Pantalla abierta: cuando termina una sincronización con respuesta del servidor, vuelve a leer lo local sin
/// mostrar "cargando". Se llama desde build (como todo ref.listen).
void reloadAfterSync(WidgetRef ref, void Function() reload) {
  ref.listen<SyncState>(syncControllerProvider, (prev, next) {
    if (syncFinished(prev, next)) reload();
  });
}
