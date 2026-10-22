import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/local_database.dart';
import '../network/dio_client.dart';
import 'pull_service.dart';

enum SyncStatus { idle, syncing, complete, mismatch, error }

class SyncState {
  final SyncStatus status;
  final PullResult? lastResult;

  /// Error del último intento (se traduce en la UI).
  final Object? error;

  /// Último pull verificado como completo (UTC, ISO), leído de sync_state.
  final String? lastCompleteAt;
  final int localMovements;
  final int localDetails;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastResult,
    this.error,
    this.lastCompleteAt,
    this.localMovements = 0,
    this.localDetails = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    PullResult? lastResult,
    Object? error,
    bool clearError = false,
    String? lastCompleteAt,
    int? localMovements,
    int? localDetails,
  }) =>
      SyncState(
        status: status ?? this.status,
        lastResult: lastResult ?? this.lastResult,
        error: clearError ? null : (error ?? this.error),
        lastCompleteAt: lastCompleteAt ?? this.lastCompleteAt,
        localMovements: localMovements ?? this.localMovements,
        localDetails: localDetails ?? this.localDetails,
      );
}

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

/// Orquesta la sincronización. En esta etapa solo descarga (pull); el envío de la cola
/// (push) llega en la etapa 6. Informa éxito solo si la verificación coincide.
class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncController(this._ref) : super(const SyncState());

  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      final db = await _ref.read(localDatabaseProvider);
      final result = await PullService(db, _ref.read(dioClientProvider)).pull();
      final counts = await _counts();
      if (!mounted) return;
      state = state.copyWith(
        status: result.complete ? SyncStatus.complete : SyncStatus.mismatch,
        lastResult: result,
        lastCompleteAt: counts.$3,
        localMovements: counts.$1,
        localDetails: counts.$2,
      );
    } catch (e) {
      debugPrint('[SYNC] Falló la sincronización: $e');
      if (!mounted) return;
      state = state.copyWith(status: SyncStatus.error, error: e);
    }
  }

  /// Lee los totales locales sin sincronizar (para mostrar el estado al abrir Ajustes).
  Future<void> refreshCounts() async {
    try {
      final c = await _counts();
      if (mounted) state = state.copyWith(localMovements: c.$1, localDetails: c.$2, lastCompleteAt: c.$3);
    } catch (e) {
      debugPrint('[SYNC] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(error: e);
    }
  }

  Future<(int, int, String?)> _counts() async {
    final db = await _ref.read(localDatabaseProvider);
    final h = (await db.rawQuery('SELECT COUNT(*) AS n FROM movement_headers WHERE deleted = 0')).first['n']! as int;
    final d = (await db.rawQuery('SELECT COUNT(*) AS n FROM movement_details WHERE deleted = 0')).first['n']! as int;
    final last = (await db.query('sync_state')).single['last_pull_at'] as String?;
    return (h, d, last);
  }
}
