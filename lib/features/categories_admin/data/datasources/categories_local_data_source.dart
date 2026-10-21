import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_local_database.dart';
import '../../domain/entities/category_admin_entity.dart';

final categoriesLocalDataSourceProvider = Provider<CategoriesLocalDataSource>((ref) {
  return CategoriesLocalDataSource();
});

class CategoriesLocalDataSource {
  Future<List<CategoryAdminEntity>> getCategories({bool todas = true}) async {
    final db = await AppLocalDatabase.instance;
    final String whereClause = todas ? "sync_status != 'pending_delete'" : "estado = 1 AND sync_status != 'pending_delete'";

    final List<Map<String, dynamic>> maps = await db.query(
      'categorias_local',
      where: whereClause,
      orderBy: 'nombre ASC',
    );

    return maps.map((m) {
      return CategoryAdminEntity(
        idCategoria: m['remote_id'] as int? ?? m['id'] as int,
        nombre: m['nombre'] as String,
        activa: (m['estado'] as int? ?? 1) == 1,
        syncId: m['sync_id'] as String?,
      );
    }).toList();
  }

  Future<void> cacheCategories(List<CategoryAdminEntity> categories) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final cat in categories) {
        final syncId = cat.syncId ?? 'cat_remote_${cat.idCategoria}';
        await txn.insert(
          'categorias_local',
          {
            'sync_id': syncId,
            'remote_id': cat.idCategoria,
            'nombre': cat.nombre,
            'estado': cat.activa ? 1 : 0,
            'sync_status': 'synced',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<CategoryAdminEntity> createCategoryLocally(String nombre) async {
    final db = await AppLocalDatabase.instance;
    final syncId = AppLocalDatabase.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();

    final id = await db.insert(
      'categorias_local',
      {
        'sync_id': syncId,
        'remote_id': null,
        'nombre': nombre,
        'estado': 1,
        'sync_status': 'pending_create',
        'created_at': now,
        'updated_at': now,
      },
    );

    return CategoryAdminEntity(
      idCategoria: id,
      nombre: nombre,
      activa: true,
      syncId: syncId,
    );
  }

  Future<CategoryAdminEntity> updateCategoryLocally({
    required int idCategoria,
    required String nombre,
    required bool activa,
    String? syncId,
  }) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idCategoria, idCategoria];

    await db.update(
      'categorias_local',
      {
        'nombre': nombre,
        'estado': activa ? 1 : 0,
        'sync_status': 'pending_update',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );

    return CategoryAdminEntity(
      idCategoria: idCategoria,
      nombre: nombre,
      activa: activa,
      syncId: syncId ?? 'cat_remote_$idCategoria',
    );
  }

  Future<void> deleteCategoryLocally(int idCategoria, {String? syncId}) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();

    final String where = syncId != null ? 'sync_id = ?' : '(remote_id = ? OR id = ?)';
    final List<dynamic> whereArgs = syncId != null ? [syncId] : [idCategoria, idCategoria];

    await db.update(
      'categorias_local',
      {
        'sync_status': 'pending_delete',
        'updated_at': now,
      },
      where: where,
      whereArgs: whereArgs,
    );
  }
}
