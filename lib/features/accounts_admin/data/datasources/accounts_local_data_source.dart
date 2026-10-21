import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_local_database.dart';
import '../../domain/entities/account_admin_entity.dart';

final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>((ref) {
  return AccountsLocalDataSource();
});

class AccountsLocalDataSource {
  Future<List<AccountAdminEntity>> getAccounts({
    bool todos = true,
    bool ocultarSaldoCero = false,
  }) async {
    final db = await AppLocalDatabase.instance;
    String whereClause = todos ? "sync_status != 'pending_delete'" : "estado = 1 AND sync_status != 'pending_delete'";

    if (ocultarSaldoCero) {
      whereClause += ' AND saldo_actual != 0.0';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'lugares_local',
      where: whereClause,
      orderBy: 'nombre ASC',
    );

    return maps.map((m) {
      return AccountAdminEntity(
        idLugar: m['remote_id'] as int? ?? m['id'] as int,
        nombre: m['nombre'] as String,
        tipoMoneda: m['tipo_moneda'] as int? ?? 1,
        saldoActual: (m['saldo_actual'] as num?)?.toDouble() ?? 0.0,
        activo: (m['estado'] as int? ?? 1) == 1,
        syncId: m['sync_id'] as String?,
      );
    }).toList();
  }

  Future<void> cacheAccounts(List<AccountAdminEntity> accounts) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final acc in accounts) {
        final syncId = acc.syncId ?? 'lug_remote_${acc.idLugar}';
        await txn.insert(
          'lugares_local',
          {
            'sync_id': syncId,
            'remote_id': acc.idLugar,
            'nombre': acc.nombre,
            'tipo_moneda': acc.tipoMoneda,
            'saldo_actual': acc.saldoActual,
            'estado': acc.activo ? 1 : 0,
            'sync_status': 'synced',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<AccountAdminEntity> createAccountLocally({
    required String nombre,
    required int tipoMoneda,
    String? img,
  }) async {
    final db = await AppLocalDatabase.instance;
    final syncId = AppLocalDatabase.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();

    final id = await db.insert(
      'lugares_local',
      {
        'sync_id': syncId,
        'remote_id': null,
        'nombre': nombre,
        'tipo_moneda': tipoMoneda,
        'saldo_actual': 0.0,
        'estado': 1,
        'sync_status': 'pending_create',
        'created_at': now,
        'updated_at': now,
      },
    );

    return AccountAdminEntity(
      idLugar: id,
      nombre: nombre,
      tipoMoneda: tipoMoneda,
      saldoActual: 0.0,
      activo: true,
      syncId: syncId,
    );
  }

  Future<AccountAdminEntity> updateAccountLocally({
    required int idLugar,
    required String nombre,
    required int tipoMoneda,
    required bool activo,
    String? syncId,
  }) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idLugar, idLugar];

    await db.update(
      'lugares_local',
      {
        'nombre': nombre,
        'tipo_moneda': tipoMoneda,
        'estado': activo ? 1 : 0,
        'sync_status': 'pending_update',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );

    return AccountAdminEntity(
      idLugar: idLugar,
      nombre: nombre,
      tipoMoneda: tipoMoneda,
      activo: activo,
      syncId: syncId ?? 'lug_remote_$idLugar',
    );
  }

  Future<void> deleteAccountLocally(int idLugar, {String? syncId}) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idLugar, idLugar];

    await db.update(
      'lugares_local',
      {
        'sync_status': 'pending_delete',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );
  }
}
