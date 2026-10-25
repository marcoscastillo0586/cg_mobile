import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database.dart';
import '../errors/exceptions.dart';
import '../network/dio_client.dart';
import '../network/server_reachability.dart';
import 'outbox.dart';
import 'pull_service.dart';
import 'push_service.dart';

/// - complete: todo lo enviado se aplicó y la base coincide con el servidor.
/// - attention: hay operaciones rechazadas, en conflicto o con error temporal (ver detalle).
/// - mismatch: la descarga no coincide con el servidor.
/// - offline: sin conexión con el servidor; se usa lo guardado y no se avisa.
enum SyncStatus { idle, syncing, complete, attention, mismatch, offline, error }

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

/// Terminó una sincronización con respuesta del servidor: las pantallas recargan lo local.
bool syncFinished(SyncState? prev, SyncState next) =>
    prev?.status == SyncStatus.syncing &&
    next.status != SyncStatus.syncing &&
    next.status != SyncStatus.offline &&
    next.status != SyncStatus.error;

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

  /// Sincroniza (si ya hay una en curso, se espera esa). Con [force] en false no se intenta si
  /// el servidor no respondió hace poco ([ServerReachability.recentlyOffline]).
  Future<void> sync({bool force = true}) {
    if (!force && ServerReachability.recentlyOffline) return Future.value();
    return _running ??= _run().whenComplete(() => _running = null);
  }

  /// Antes de mostrar una pantalla: trae lo que cambió en el servidor, sin esperar si se sabe
  /// que no hay conexión.
  Future<void> refreshIfOnline() => sync(force: false);

  /// Envía ya lo que acaba de guardar el usuario, detrás de lo pendiente y en orden.
  /// Devuelve el rechazo del servidor por una regla de negocio, si lo hubo: esa operación se
  /// descarta (el cambio local ya se revirtió). Sin conexión no espera ni avisa: queda en la cola.
  Future<Object?> sendNow() async {
    final ops = Outbox.takeRecent();
    if (ops.isEmpty || ServerReachability.recentlyOffline) return null;
    final running = _running;
    if (running != null) await running; // pudo haber leído la cola antes de esta operación
    await sync();
    final db = await _ref.read(localDatabaseProvider);
    final rows = await db.query('outbox',
        where: "status = 'rejected' AND op_id IN (${List.filled(ops.length, '?').join(',')})", whereArgs: ops, orderBy: 'seq');
    if (rows.isEmpty) return null;
    Object? rejection;
    for (final r in rows) {
      final result = r['server_result'] == null ? null : jsonDecode(r['server_result']! as String);
      final error = result is Map<String, dynamic> ? result['error'] as Map<String, dynamic>? : null;
      rejection ??= ServerException(error?['message'] as String? ?? '', null, error?['code'] as String? ?? 'REJECTED');
      await db.delete('outbox', where: 'seq = ?', whereArgs: [r['seq']]);
    }
    await refreshCounts();
    return rejection;
  }

  Future<void> _run() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      final db = await _ref.read(localDatabaseProvider);
      final client = _ref.read(dioClientProvider);
      var pushed = await PushService(db, client).push();
      PullResult? pulled;
      if (pushed.count('pending') == 0) {
        pulled = await PullService(db, client).pull();
        if (await _resolveConflicts(db) > 0) {
          pushed = await PushService(db, client).push();
          if (pushed.count('pending') == 0) {
            // La descarga del servidor no incluye los últimos 2 s: se espera para traer lo reenviado.
            await Future<void>.delayed(const Duration(milliseconds: 2100));
            pulled = await PullService(db, client).pull();
          }
        }
      }
      final c = await _counts();
      if (!mounted) return;
      final SyncStatus status;
      if (pushed.count('pending') > 0) {
        status = SyncStatus.offline; // error temporal del servidor: queda en la cola, sin aviso
      } else if (pushed.count('rejected') > 0) {
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
      if (!mounted) return;
      state = ServerReachability.isOfflineError(e)
          ? state.copyWith(status: SyncStatus.offline)
          : state.copyWith(status: SyncStatus.error, error: e);
    }
  }

  /// Vale el último cambio: la hora del cambio en el celular contra la del último cambio en el
  /// servidor (`updated_at`, recién descargado). Si el del celular es posterior se reenvía como
  /// operación NUEVA sobre la versión actual (el servidor guarda el resultado de cada opId y
  /// repetiría el conflicto); si no, se descarta (lo del servidor ya quedó en el celular).
  /// Devuelve cuántas se reenviaron.
  static Future<int> _resolveConflicts(Database db) async {
    final ops = await db.query('outbox', where: "status = 'conflict'", orderBy: 'seq');
    var resent = 0;
    for (final op in ops) {
      final table = Outbox.tables[op['entity']];
      final ref = op['ref'] == null ? null : jsonDecode(op['ref']! as String);
      final serverId = ref is Map<String, dynamic> ? ref['serverId'] : null;
      final row = table == null || serverId is! int
          ? null
          : (await db.query(table, columns: ['version', 'updated_at'], where: 'server_id = ?', whereArgs: [serverId])).firstOrNull;
      final changedAt = DateTime.tryParse(op['created_at']! as String);
      final serverAt = DateTime.tryParse(row?['updated_at'] as String? ?? '');
      final phoneWins = row != null && changedAt != null && serverAt != null && changedAt.isAfter(serverAt);
      debugPrint('[SYNC] Conflicto #${op['seq']}: ${phoneWins ? 'gana el celular, se reenvía' : 'gana el servidor'}');
      await db.transaction((txn) async {
        if (phoneWins) {
          await txn.insert('outbox', {
            ...op,
            'seq': null,
            'op_id': LocalDatabase.newId(),
            'base_version': row['version'],
            'status': 'pending',
            'server_result': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          resent++;
        }
        await txn.delete('outbox', where: 'seq = ?', whereArgs: [op['seq']]);
      });
    }
    return resent;
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
