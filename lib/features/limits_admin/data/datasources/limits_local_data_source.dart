import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_local_database.dart';
import '../../domain/entities/expense_limit_admin_entity.dart';

final limitsLocalDataSourceProvider = Provider<LimitsLocalDataSource>((ref) {
  return LimitsLocalDataSource();
});

class LimitsLocalDataSource {
  Future<List<ExpenseLimitAdminEntity>> getLimits() async {
    final db = await AppLocalDatabase.instance;

    final List<Map<String, dynamic>> maps = await db.query(
      'limites_local',
      where: "sync_status != 'pending_delete'",
      orderBy: 'created_at DESC',
    );

    final now = DateTime.now();
    final inicioMesStr = DateTime(now.year, now.month, 1).toIso8601String();
    final finMesStr = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

    final List<ExpenseLimitAdminEntity> result = [];
    for (final m in maps) {
      final catRemoteId = m['categoria_remote_id'] as int?;
      final limitAmount = (m['monto_limite'] as num).toDouble();

      double totalGastadoLocal = 0.0;
      if (catRemoteId != null && catRemoteId > 0) {
        final List<Map<String, dynamic>> sumRes = await db.rawQuery(
          "SELECT SUM(ABS(monto)) as total FROM movimiento_det_local WHERE (categoria_remote_id = ? OR categoria_sync_id = ?) AND sync_status != 'pending_delete' AND created_at >= ? AND created_at <= ?",
          [catRemoteId, 'cat_remote_$catRemoteId', inicioMesStr, finMesStr],
        );
        if (sumRes.isNotEmpty && sumRes.first['total'] != null) {
          totalGastadoLocal = (sumRes.first['total'] as num).toDouble();
        }
      } else {
        final List<Map<String, dynamic>> sumRes = await db.rawQuery(
          "SELECT SUM(ABS(monto)) as total FROM movimiento_det_local WHERE sync_status != 'pending_delete' AND created_at >= ? AND created_at <= ?",
          [inicioMesStr, finMesStr],
        );
        if (sumRes.isNotEmpty && sumRes.first['total'] != null) {
          totalGastadoLocal = (sumRes.first['total'] as num).toDouble();
        }
      }

      final porcentaje = limitAmount > 0 ? (totalGastadoLocal / limitAmount) * 100 : 0.0;
      final resto = limitAmount - totalGastadoLocal;

      final desde = DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime(now.year, now.month, 1);
      final hasta = DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime(now.year, now.month + 1, 0);

      result.add(
        ExpenseLimitAdminEntity(
          idLimiteGasto: m['remote_id'] as int? ?? m['id'] as int,
          desde: desde,
          hasta: hasta,
          montoLimite: limitAmount,
          montoConsumido: totalGastadoLocal,
          resto: resto,
          porcentaje: porcentaje,
          vencido: hasta.isBefore(DateTime.now()),
          categoria: catRemoteId != null ? catRemoteId.toString() : '',
          categoriasNombres: 'Categoría ${catRemoteId ?? "General"}',
          lugar: '',
          lugaresNombres: 'Todas las cuentas',
          syncId: m['sync_id'] as String?,
        ),
      );
    }

    return result;
  }

  Future<void> cacheLimits(List<ExpenseLimitAdminEntity> limits) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final lim in limits) {
        final syncId = lim.syncId ?? 'lim_remote_${lim.idLimiteGasto}';
        final catId = lim.categoriasIds.isNotEmpty ? lim.categoriasIds.first : null;

        await txn.insert(
          'limites_local',
          {
            'sync_id': syncId,
            'remote_id': lim.idLimiteGasto,
            'categoria_sync_id': catId != null ? 'cat_remote_$catId' : null,
            'categoria_remote_id': catId,
            'monto_limite': lim.montoLimite,
            'periodo': 'mensual',
            'sync_status': 'synced',
            'created_at': lim.desde.toUtc().toIso8601String(),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<ExpenseLimitAdminEntity> createLimitLocally({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  }) async {
    final db = await AppLocalDatabase.instance;
    final syncId = AppLocalDatabase.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final catId = categoriasIds.isNotEmpty ? categoriasIds.first : 0;

    final id = await db.insert(
      'limites_local',
      {
        'sync_id': syncId,
        'remote_id': null,
        'categoria_sync_id': 'cat_remote_$catId',
        'categoria_remote_id': catId,
        'monto_limite': montoLimite,
        'periodo': 'mensual',
        'sync_status': 'pending_create',
        'created_at': desde.toUtc().toIso8601String(),
        'updated_at': now,
      },
    );

    return ExpenseLimitAdminEntity(
      idLimiteGasto: id,
      desde: desde,
      hasta: hasta,
      montoLimite: montoLimite,
      montoConsumido: 0.0,
      resto: montoLimite,
      porcentaje: 0.0,
      vencido: false,
      categoria: catId > 0 ? catId.toString() : '',
      categoriasNombres: 'Categoría $catId',
      lugar: '',
      lugaresNombres: 'Todas las cuentas',
      syncId: syncId,
    );
  }

  Future<bool> updateLimitLocally({
    required int idLimiteGasto,
    required double montoLimite,
    String? syncId,
  }) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idLimiteGasto, idLimiteGasto];

    await db.update(
      'limites_local',
      {
        'monto_limite': montoLimite,
        'sync_status': 'pending_update',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );

    return true;
  }

  Future<bool> deleteLimitLocally(int idLimiteGasto, {String? syncId}) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idLimiteGasto, idLimiteGasto];

    await db.update(
      'limites_local',
      {
        'sync_status': 'pending_delete',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );

    return true;
  }
}
