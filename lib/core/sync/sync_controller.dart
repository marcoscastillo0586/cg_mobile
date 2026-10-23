import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/local_database.dart';
import '../network/dio_client.dart';
import 'pull_service.dart';
import 'push_service.dart';

/// - complete: todo lo enviado se aplicó y la base coincide con el servidor.
/// - attention: hay operaciones rechazadas, en conflicto o con error temporal (ver detalle).
/// - mismatch: la descarga no coincide con el servidor.
enum SyncStatus { idle, syncing, complete, attention, mismatch, error }

class SyncState {
  final SyncStatus status;
  final PullResult? lastResult;
  final PushResult? lastPush;

  /// Error del último intento (se traduce en la UI).
  final Object? error;

  /// Último pull verificado como completo (UTC, ISO), leído de sync_state.
  final String? lastCompleteAt;
  final int localMovements;
  final int localDetails;

  /// Operaciones de la outbox por estado.
  final int pendingOps;
  final int rejectedOps;
  final int conflictOps;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastResult,
    this.lastPush,
    this.error,
    this.lastCompleteAt,
    this.localMovements = 0,
    this.localDetails = 0,
    this.pendingOps = 0,
    this.rejectedOps = 0,
    this.conflictOps = 0,
  });

  int get needsAttention => rejectedOps + conflictOps;

  SyncState copyWith({
    SyncStatus? status,
    PullResult? lastResult,
    PushResult? lastPush,
    Object? error,
    bool clearError = false,
    String? lastCompleteAt,
    int? localMovements,
    int? localDetails,
    int? pendingOps,
    int? rejectedOps,
    int? conflictOps,
  }) =>
      SyncState(
        status: status ?? this.status,
        lastResult: lastResult ?? this.lastResult,
        lastPush: lastPush ?? this.lastPush,
        error: clearError ? null : (error ?? this.error),
        lastCompleteAt: lastCompleteAt ?? this.lastCompleteAt,
        localMovements: localMovements ?? this.localMovements,
        localDetails: localDetails ?? this.localDetails,
        pendingOps: pendingOps ?? this.pendingOps,
        rejectedOps: rejectedOps ?? this.rejectedOps,
        conflictOps: conflictOps ?? this.conflictOps,
      );
}

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

/// EL sincronizador de la app (único que habla con el servidor para escribir).
/// Una sola sincronización a la vez: una llamada concurrente espera la que está en curso.
/// Orden: primero envía la outbox (push) y después descarga (pull). Si quedaron operaciones
/// pendientes por error temporal no descarga, para no pisar cambios locales sin enviar.
/// Informa éxito solo si todo se aplicó y la descarga coincide; si no, deja el detalle.
class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;
  Future<void>? _running;

  SyncController(this._ref) : super(const SyncState());

  Future<void> sync() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      final db = await _ref.read(localDatabaseProvider);
      final client = _ref.read(dioClientProvider);
      final pushed = await PushService(db, client).push();
      PullResult? pulled;
      if (pushed.count('pending') == 0) pulled = await PullService(db, client).pull();
      final c = await _counts();
      if (!mounted) return;
      final SyncStatus status;
      if (!pushed.complete) {
        status = SyncStatus.attention;
      } else if (pulled != null && !pulled.complete) {
        status = SyncStatus.mismatch;
      } else {
        status = SyncStatus.complete;
      }
      if (!pushed.complete) debugPrint('[SYNC] Envío incompleto: ${pushed.issues.join(' | ')}');
      state = _withCounts(state.copyWith(status: status, lastPush: pushed, lastResult: pulled), c);
    } catch (e) {
      debugPrint('[SYNC] Falló la sincronización: $e');
      try {
        final c = await _counts();
        if (mounted) state = _withCounts(state, c);
      } catch (inner) {
        debugPrint('[SYNC] Tampoco se pudo leer la base local: $inner');
      }
      if (mounted) state = state.copyWith(status: SyncStatus.error, error: e);
    }
  }

  /// Lee los totales locales sin sincronizar (para mostrar el estado al abrir Ajustes).
  Future<void> refreshCounts() async {
    try {
      final c = await _counts();
      if (mounted) state = _withCounts(state, c);
    } catch (e) {
      debugPrint('[SYNC] No se pudo leer la base local: $e');
      if (mounted) state = state.copyWith(error: e);
    }
  }

  static SyncState _withCounts(SyncState s, _Counts c) => s.copyWith(
        localMovements: c.headers,
        localDetails: c.details,
        lastCompleteAt: c.lastPull,
        pendingOps: c.byStatus['pending'] ?? 0,
        rejectedOps: c.byStatus['rejected'] ?? 0,
        conflictOps: c.byStatus['conflict'] ?? 0,
      );

  Future<_Counts> _counts() async {
    final db = await _ref.read(localDatabaseProvider);
    final h = (await db.rawQuery('SELECT COUNT(*) AS n FROM movement_headers WHERE deleted = 0')).first['n']! as int;
    final d = (await db.rawQuery('SELECT COUNT(*) AS n FROM movement_details WHERE deleted = 0')).first['n']! as int;
    final last = (await db.query('sync_state')).single['last_pull_at'] as String?;
    final byStatus = {
      for (final r in await db.rawQuery('SELECT status, COUNT(*) AS n FROM outbox GROUP BY status')) r['status']! as String: r['n']! as int,
    };
    return _Counts(h, d, last, byStatus);
  }
}

class _Counts {
  final int headers;
  final int details;
  final String? lastPull;
  final Map<String, int> byStatus;
  const _Counts(this.headers, this.details, this.lastPull, this.byStatus);
}
