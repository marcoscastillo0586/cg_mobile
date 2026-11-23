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
    for (final r in rows) {
      await db.delete('outbox', where: 'seq = ?', whereArgs: [r['seq']]);
    }
    await refreshCounts();
    return _rejection(rows.first);
  }

  /// El rechazo del servidor guardado en la operación.
  static ServerException _rejection(Map<String, Object?> op) {
    final result = op['server_result'] == null ? null : jsonDecode(op['server_result']! as String);
    final error = result is Map<String, dynamic> ? result['error'] as Map<String, dynamic>? : null;
    return ServerException(error?['message'] as String? ?? '', null, error?['code'] as String? ?? 'REJECTED');
  }

  Future<void> _run() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      final (pushed, pulled) = await _pushThenPull(await _ref.read(localDatabaseProvider), _ref.read(dioClientProvider));
      final c = await _counts();
      if (!mounted) return;
      if (!pushed.complete) debugPrint('[SYNC] Envío incompleto: ${pushed.issues.join(' | ')}');
      state = _withCounts(state.copyWith(status: statusAfter(pushed, pulled), lastPush: pushed, lastResult: pulled), c);
    } catch (e) {
      debugPrint('[SYNC] Falló la sincronización: $e');
      await _failed(e);
    }
  }

  /// Envía y, si no quedó nada pendiente, descarga. Si al descargar hubo conflictos que ganó el celular,
  /// los reenvía y vuelve a descargar.
  static Future<(PushResult, PullResult?)> _pushThenPull(Database db, DioClient client) async {
    final pushed = await PushService(db, client).push();
    if (pushed.count('pending') > 0) return (pushed, null);
    final pulled = await PullService(db, client).pull();
    if (await _resolveConflicts(db) == 0) return (pushed, pulled);
    final resent = await PushService(db, client).push();
    if (resent.count('pending') > 0) return (resent, pulled);
    // La descarga del servidor no incluye los últimos 2 s: se espera para traer lo reenviado.
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    return (resent, await PullService(db, client).pull());
  }

  /// Sin conexión (o error temporal) queda como "sin conexión", sin aviso; otro error se muestra.
  Future<void> _failed(Object e) async {
    try {
      final c = await _counts();
      if (mounted) state = _withCounts(state, c);
    } catch (inner) {
      debugPrint('[SYNC] Tampoco se pudo leer la base local: $inner');
    }
    if (!mounted) return;
    state = ServerReachability.isOfflineError(e) ? state.copyWith(status: SyncStatus.offline) : state.copyWith(status: SyncStatus.error, error: e);
  }

  /// Estado al terminar: lo pendiente por error temporal es "sin conexión" (sin aviso); un rechazo pide
  /// atención; una descarga que no coincide con el servidor, diferencias; si no, completa.
  @visibleForTesting
  static SyncStatus statusAfter(PushResult pushed, PullResult? pulled) {
    if (pushed.count('pending') > 0) return SyncStatus.offline;
    if (pushed.count('rejected') > 0) return SyncStatus.attention;
    if (pulled != null && !pulled.complete) return SyncStatus.mismatch;
    return SyncStatus.complete;
  }

  @visibleForTesting
  static Future<int> resolveConflicts(Database db) => _resolveConflicts(db);

  /// Vale el último cambio: la hora del cambio en el celular contra la del último cambio en el
  /// servidor (`updated_at`, recién descargado). Si el del celular es posterior se reenvía como
  /// operación NUEVA sobre la versión actual (el servidor guarda el resultado de cada opId y
  /// repetiría el conflicto); si no, se descarta (lo del servidor ya quedó en el celular).
  /// Devuelve cuántas se reenviaron.
  static Future<int> _resolveConflicts(Database db) async {
    final ops = await db.query('outbox', where: "status = 'conflict'", orderBy: 'seq');
    var resent = 0;
    for (final op in ops) {
      final row = await _serverRow(db, op);
      final phoneWins = row != null && _isAfter(op['created_at'] as String?, row['updated_at'] as String?);
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

  /// Versión y última modificación (ya descargadas) del registro del servidor al que apunta la operación.
  static Future<Map<String, Object?>?> _serverRow(Database db, Map<String, Object?> op) async {
    final table = Outbox.tables[op['entity']];
    final ref = op['ref'] == null ? null : jsonDecode(op['ref']! as String);
    final serverId = ref is Map<String, dynamic> ? ref['serverId'] : null;
    if (table == null || serverId is! int) return null;
    return (await db.query(table, columns: ['version', 'updated_at'], where: 'server_id = ?', whereArgs: [serverId])).firstOrNull;
  }

  static bool _isAfter(String? a, String? b) {
    final x = DateTime.tryParse(a ?? '');
    final y = DateTime.tryParse(b ?? '');
    return x != null && y != null && x.isAfter(y);
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
