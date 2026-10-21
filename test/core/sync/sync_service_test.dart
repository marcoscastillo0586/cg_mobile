import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/sync/sync_state.dart';

void main() {
  group('SyncState and SyncResult Unit Tests', () {
    test('SyncState.initial() crea estado por defecto en idle', () {
      final state = SyncState.initial();

      expect(state.status, equals(SyncStatus.idle));
      expect(state.message, isNull);
      expect(state.itemsPushed, equals(0));
      expect(state.itemsPulled, equals(0));
    });

    test('SyncState.copyWith actualiza campos correctamente', () {
      final state = SyncState.initial();
      final updated = state.copyWith(
        status: SyncStatus.success,
        message: 'Sincronizado con éxito',
        itemsPushed: 3,
        itemsPulled: 5,
      );

      expect(updated.status, equals(SyncStatus.success));
      expect(updated.message, equals('Sincronizado con éxito'));
      expect(updated.itemsPushed, equals(3));
      expect(updated.itemsPulled, equals(5));
    });

    test('SyncResult empaqueta resultados de sincronización', () {
      const result = SyncResult(
        success: true,
        itemsCount: 12,
        message: 'Cambios subidos',
      );

      expect(result.success, isTrue);
      expect(result.itemsCount, equals(12));
      expect(result.message, equals('Cambios subidos'));
    });
  });
}
