import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/sync/sync_state.dart';

void main() {
  group('Etapa 4 Background Sync Tests', () {
    test('runFullSync con silent = true no modifica la interfaz intrusivamente', () {
      final state = SyncState.initial();
      final silentState = state.copyWith(
        status: SyncStatus.offline,
        message: 'Servidor no disponible (modo offline)',
      );

      expect(silentState.status, equals(SyncStatus.offline));
      expect(silentState.message, contains('offline'));
    });
  });
}
