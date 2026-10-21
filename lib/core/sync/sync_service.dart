import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/api_endpoints.dart';
import '../database/app_local_database.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';
import 'sync_state.dart';

final syncServiceProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final storageService = ref.watch(secureStorageServiceProvider);
  return SyncNotifier(dioClient, storageService);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  static const String _keyLastSyncedAt = 'last_synced_at_timestamp';

  SyncNotifier(this._dioClient, this._storageService)
      : super(SyncState.initial());

  /// 1. Verifica disponibilidad rápida del servidor en la red local (3s timeout)
  Future<bool> checkServerAvailability() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final response = await dio.get<dynamic>('${ApiEndpoints.baseUrl}/api/dashboard/saldos');
      final isOk = response.statusCode == 200 || response.statusCode == 401;
      if (kDebugMode) {
        debugPrint('[SYNC-DEBUG] [PING] Servidor 192.168.0.50 responde: $isOk');
      }
      return isOk;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SYNC-DEBUG] [PING] Servidor 192.168.0.50 no disponible (Modo Offline): $e');
      }
      return false;
    }
  }

  /// 2. Empaqueta y sube cambios locales pendientes al servidor (PUSH)
  Future<SyncResult> pushLocalChanges() async {
    final db = await AppLocalDatabase.instance;

    final pendingCategories = await db.query(
      'categorias_local',
      where: "sync_status IN ('pending_create', 'pending_update', 'pending_delete')",
    );

    final pendingLugares = await db.query(
      'lugares_local',
      where: "sync_status IN ('pending_create', 'pending_update', 'pending_delete')",
    );

    final pendingLimites = await db.query(
      'limites_local',
      where: "sync_status IN ('pending_create', 'pending_update', 'pending_delete')",
    );

    final pendingEnc = await db.query(
      'movimiento_enc_local',
      where: "sync_status IN ('pending_create', 'pending_update', 'pending_delete')",
    );

    final pendingDet = await db.query(
      'movimiento_det_local',
      where: "sync_status IN ('pending_create', 'pending_update', 'pending_delete')",
    );

    final totalPending = pendingCategories.length +
        pendingLugares.length +
        pendingLimites.length +
        pendingEnc.length +
        pendingDet.length;

    if (kDebugMode) {
      debugPrint('[SYNC-DEBUG] [PUSH] Cambios pendientes locales: $totalPending (Cats: ${pendingCategories.length}, Lugs: ${pendingLugares.length}, Enc: ${pendingEnc.length})');
    }

    if (totalPending == 0) {
      return const SyncResult(
        success: true,
        itemsCount: 0,
        message: 'Sin cambios locales pendientes',
      );
    }

    final payload = {
      'categorias': pendingCategories,
      'lugares': pendingLugares,
      'limites': pendingLimites,
      'movimientos_enc': pendingEnc,
      'movimientos_det': pendingDet,
    };

    try {
      final response = await _dioClient.post(
        '${ApiEndpoints.baseUrl}/api/sync/push',
        data: payload,
      );

      Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response;
        }
      } else {
        data = {};
      }

      final processedSyncIds = List<String>.from(data['processed_sync_ids'] as List? ?? []);

      if (processedSyncIds.isNotEmpty) {
        await db.transaction((txn) async {
          for (final syncId in processedSyncIds) {
            await txn.update('categorias_local', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [syncId]);
            await txn.update('lugares_local', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [syncId]);
            await txn.update('limites_local', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [syncId]);
            await txn.update('movimiento_enc_local', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [syncId]);
            await txn.update('movimiento_det_local', {'sync_status': 'synced'}, where: 'sync_id = ?', whereArgs: [syncId]);
          }
        });
      }

      if (kDebugMode) {
        debugPrint('[SYNC-DEBUG] [PUSH] Servidor procesó exitosamente ${processedSyncIds.length} registros.');
      }

      return SyncResult(
        success: true,
        itemsCount: processedSyncIds.length,
        message: 'Cambios subidos al servidor',
      );
    } catch (e) {
      debugPrint('[SYNC-DEBUG] [PUSH] Error en pushLocalChanges: $e');
      return SyncResult(
        success: false,
        itemsCount: 0,
        message: 'Error al subir cambios locales: $e',
      );
    }
  }

  /// 3. Descarga novedades del servidor y aplica Last-Write-Wins con paginado completo
  Future<SyncResult> pullServerChanges() async {
    final db = await AppLocalDatabase.instance;

    // Verificar si las tablas principales están vacías en SQLite local
    final catCountRes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categorias_local')) ?? 0;
    final lugCountRes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM lugares_local')) ?? 0;
    final encCountRes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM movimiento_enc_local')) ?? 0;

    final bool forceFullSync = (catCountRes == 0 || lugCountRes == 0 || encCountRes == 0);

    String? lastSyncedAt = await _storageService.readValue(_keyLastSyncedAt);
    if (forceFullSync) {
      lastSyncedAt = null; // Forzar descarga total de la base MySQL
      if (kDebugMode) {
        debugPrint('[SYNC-DEBUG] [PULL] Tablas locales vacías en SQLite (Cats: $catCountRes, Lugs: $lugCountRes, Movs: $encCountRes). Forzando descarga completa inicial del servidor MySQL...');
      }
    }

    int offset = 0;
    const limit = 500;
    bool hasMore = true;
    int totalPulled = 0;

    try {
      while (hasMore) {
        final response = await _dioClient.get(
          '${ApiEndpoints.baseUrl}/api/sync/pull',
          queryParameters: {
            if (lastSyncedAt != null && lastSyncedAt.isNotEmpty) 'since': lastSyncedAt,
            'offset': offset,
            'limit': limit,
          },
        );

        Map<String, dynamic> data;
        if (response is Map<String, dynamic>) {
          if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
            data = response['data'] as Map<String, dynamic>;
          } else {
            data = response;
          }
        } else {
          data = {};
        }

        final serverTimestamp = data['server_timestamp'] as String? ?? DateTime.now().toUtc().toIso8601String();
        hasMore = data['has_more'] as bool? ?? false;
        final remoteCategories = List<Map<String, dynamic>>.from(data['categorias'] as List? ?? []);
        final remoteLugares = List<Map<String, dynamic>>.from(data['lugares'] as List? ?? []);
        final remoteLimites = List<Map<String, dynamic>>.from(data['limites'] as List? ?? []);
        final remoteEnc = List<Map<String, dynamic>>.from(data['movimientos_enc'] as List? ?? []);
        final remoteDet = List<Map<String, dynamic>>.from(data['movimientos_det'] as List? ?? []);

        await db.transaction((txn) async {
          // Categorías
          for (final cat in remoteCategories) {
            final syncId = cat['sync_id']?.toString() ?? 'cat_remote_${cat['id_categoria']}';
            final existing = await txn.query('categorias_local', where: 'sync_id = ?', whereArgs: [syncId]);

            if (existing.isEmpty) {
              await txn.insert('categorias_local', {
                'sync_id': syncId,
                'remote_id': cat['id_categoria'],
                'nombre': cat['nombre'],
                'estado': (cat['estado'] as int? ?? 1),
                'sync_status': 'synced',
                'created_at': cat['created_at'] ?? serverTimestamp,
                'updated_at': cat['updated_at'] ?? serverTimestamp,
              });
              totalPulled++;
            } else {
              final local = existing.first;
              if (local['sync_status'] == 'synced') {
                await txn.update(
                  'categorias_local',
                  {
                    'remote_id': cat['id_categoria'],
                    'nombre': cat['nombre'],
                    'estado': (cat['estado'] as int? ?? 1),
                    'updated_at': cat['updated_at'] ?? serverTimestamp,
                  },
                  where: 'sync_id = ?',
                  whereArgs: [syncId],
                );
                totalPulled++;
              }
            }
          }

          // Lugares / Cuentas con saldo real y metadatos
          for (final lug in remoteLugares) {
            final syncId = lug['sync_id']?.toString() ?? 'lug_remote_${lug['id_lugar']}';
            final existing = await txn.query('lugares_local', where: 'sync_id = ?', whereArgs: [syncId]);
            final double saldoServer = (lug['saldo_actual'] as num?)?.toDouble() ??
                (lug['montoOriginal'] as num?)?.toDouble() ??
                0.0;

            if (existing.isEmpty) {
              await txn.insert('lugares_local', {
                'sync_id': syncId,
                'remote_id': lug['id_lugar'],
                'nombre': lug['nombre'],
                'tipo_moneda': lug['tipoMoneda'] ?? 1,
                'simbolo_moneda': (lug['tipoMoneda'] == 2) ? 'US\$' : '\$',
                'monto_original': saldoServer,
                'monto_pesos': (lug['tipoMoneda'] == 2) ? saldoServer * 1000.0 : saldoServer,
                'cotizacion': (lug['tipoMoneda'] == 2) ? 1000.0 : 1.0,
                'saldo_actual': saldoServer,
                'estado': (lug['estado'] as int? ?? 1),
                'img_url': lug['img'] as String?,
                'sync_status': 'synced',
                'created_at': serverTimestamp,
                'updated_at': serverTimestamp,
              });
              totalPulled++;
            } else {
              final local = existing.first;
              if (local['sync_status'] == 'synced') {
                await txn.update(
                  'lugares_local',
                  {
                    'remote_id': lug['id_lugar'],
                    'nombre': lug['nombre'],
                    'tipo_moneda': lug['tipoMoneda'] ?? 1,
                    'simbolo_moneda': (lug['tipoMoneda'] == 2) ? 'US\$' : '\$',
                    'monto_original': saldoServer,
                    'monto_pesos': (lug['tipoMoneda'] == 2) ? saldoServer * 1000.0 : saldoServer,
                    'cotizacion': (lug['tipoMoneda'] == 2) ? 1000.0 : 1.0,
                    'saldo_actual': saldoServer,
                    'estado': (lug['estado'] as int? ?? 1),
                    'img_url': lug['img'] as String?,
                    'updated_at': serverTimestamp,
                  },
                  where: 'sync_id = ?',
                  whereArgs: [syncId],
                );
                totalPulled++;
              }
            }
          }

          // Límites de Gasto
          for (final lim in remoteLimites) {
            final syncId = lim['sync_id']?.toString() ?? 'lim_remote_${lim['id_limite_gasto']}';
            final existing = await txn.query('limites_local', where: 'sync_id = ?', whereArgs: [syncId]);

            if (existing.isEmpty) {
              await txn.insert('limites_local', {
                'sync_id': syncId,
                'remote_id': lim['id_limite_gasto'],
                'categoria_sync_id': 'cat_remote_${lim['categoria_remote_id']}',
                'categoria_remote_id': lim['categoria_remote_id'],
                'monto_limite': (lim['monto_limite'] as num?)?.toDouble() ?? 0.0,
                'periodo': 'mensual',
                'sync_status': 'synced',
                'created_at': lim['created_at'] ?? serverTimestamp,
                'updated_at': lim['updated_at'] ?? serverTimestamp,
              });
              totalPulled++;
            } else {
              final local = existing.first;
              if (local['sync_status'] == 'synced') {
                await txn.update(
                  'limites_local',
                  {
                    'remote_id': lim['id_limite_gasto'],
                    'categoria_sync_id': 'cat_remote_${lim['categoria_remote_id']}',
                    'categoria_remote_id': lim['categoria_remote_id'],
                    'monto_limite': (lim['monto_limite'] as num?)?.toDouble() ?? 0.0,
                    'updated_at': lim['updated_at'] ?? serverTimestamp,
                  },
                  where: 'sync_id = ?',
                  whereArgs: [syncId],
                );
                totalPulled++;
              }
            }
          }

          // Movimientos Encabezado
          for (final enc in remoteEnc) {
            final syncId = enc['sync_id']?.toString() ?? 'enc_remote_${enc['id_movimiento_enc']}';
            final existing = await txn.query('movimiento_enc_local', where: 'sync_id = ?', whereArgs: [syncId]);

            if (existing.isEmpty) {
              await txn.insert('movimiento_enc_local', {
                'sync_id': syncId,
                'remote_id': enc['id_movimiento_enc'],
                'tipo_movimiento': enc['tipo_movimiento'] ?? 2,
                'concepto_general': enc['concepto_general'] ?? 'Gasto',
                'fecha_movimiento': enc['fecha_movimiento'] ?? serverTimestamp,
                'sync_status': 'synced',
                'created_at': serverTimestamp,
                'updated_at': serverTimestamp,
              });
              totalPulled++;
            } else {
              final local = existing.first;
              if (local['sync_status'] == 'synced') {
                await txn.update(
                  'movimiento_enc_local',
                  {
                    'remote_id': enc['id_movimiento_enc'],
                    'tipo_movimiento': enc['tipo_movimiento'] ?? 2,
                    'concepto_general': enc['concepto_general'] ?? 'Gasto',
                    'fecha_movimiento': enc['fecha_movimiento'] ?? serverTimestamp,
                    'updated_at': serverTimestamp,
                  },
                  where: 'sync_id = ?',
                  whereArgs: [syncId],
                );
                totalPulled++;
              }
            }
          }

          // Movimientos Detalle / Renglones
          for (final det in remoteDet) {
            final syncId = det['sync_id']?.toString() ?? 'det_remote_${det['id_movimiento_det']}';
            final existing = await txn.query('movimiento_det_local', where: 'sync_id = ?', whereArgs: [syncId]);

            if (existing.isEmpty) {
              await txn.insert('movimiento_det_local', {
                'sync_id': syncId,
                'remote_id': det['id_movimiento_det'],
                'movimiento_enc_sync_id': det['movimiento_enc_sync_id'] ?? 'enc_remote_${det['id_movimiento_enc']}',
                'lugar_sync_id': 'lug_remote_${det['lugar_remote_id']}',
                'lugar_remote_id': det['lugar_remote_id'],
                'categoria_sync_id': 'cat_remote_${det['categoria_remote_id']}',
                'categoria_remote_id': det['categoria_remote_id'],
                'concepto': det['concepto'] ?? 'Gasto',
                'monto': (det['monto'] as num?)?.toDouble() ?? 0.0,
                'sync_status': 'synced',
                'created_at': serverTimestamp,
                'updated_at': serverTimestamp,
              });
              totalPulled++;
            } else {
              final local = existing.first;
              if (local['sync_status'] == 'synced') {
                await txn.update(
                  'movimiento_det_local',
                  {
                    'remote_id': det['id_movimiento_det'],
                    'movimiento_enc_sync_id': det['movimiento_enc_sync_id'] ?? 'enc_remote_${det['id_movimiento_enc']}',
                    'lugar_sync_id': 'lug_remote_${det['lugar_remote_id']}',
                    'lugar_remote_id': det['lugar_remote_id'],
                    'categoria_sync_id': 'cat_remote_${det['categoria_remote_id']}',
                    'categoria_remote_id': det['categoria_remote_id'],
                    'concepto': det['concepto'] ?? 'Gasto',
                    'monto': (det['monto'] as num?)?.toDouble() ?? 0.0,
                    'updated_at': serverTimestamp,
                  },
                  where: 'sync_id = ?',
                  whereArgs: [syncId],
                );
                totalPulled++;
              }
            }
          }
        });

        await _storageService.writeValue(_keyLastSyncedAt, serverTimestamp);
        offset += remoteEnc.length;

        if (remoteEnc.isEmpty) break;
      }

      if (kDebugMode) {
        debugPrint('[SYNC-DEBUG] [PULL] Paginado completado. Total registros procesados en SQLite: $totalPulled');
      }

      return SyncResult(
        success: true,
        itemsCount: totalPulled,
        message: 'Datos e historial descargados del servidor',
      );
    } catch (e) {
      debugPrint('[SYNC-DEBUG] [PULL] Error en pullServerChanges: $e');
      return SyncResult(
        success: false,
        itemsCount: 0,
        message: 'Error al descargar datos del servidor: $e',
      );
    }
  }

  /// 4. Orquestador de sincronización completa secuencial
  Future<void> runFullSync({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: SyncStatus.syncing, message: 'Verificando red...');
    }

    final isAvailable = await checkServerAvailability();
    if (!isAvailable) {
      state = state.copyWith(
        status: SyncStatus.offline,
        message: 'Servidor no disponible (modo offline)',
      );
      return;
    }

    if (!silent) {
      state = state.copyWith(status: SyncStatus.syncing, message: 'Subiendo cambios...');
    }
    final pushRes = await pushLocalChanges();

    if (!silent) {
      state = state.copyWith(status: SyncStatus.syncing, message: 'Descargando novedades...');
    }
    final pullRes = await pullServerChanges();

    final now = DateTime.now();
    state = state.copyWith(
      status: SyncStatus.success,
      message: 'Sincronizado con éxito',
      lastSyncedAt: now,
      itemsPushed: pushRes.itemsCount,
      itemsPulled: pullRes.itemsCount,
    );
  }
}
