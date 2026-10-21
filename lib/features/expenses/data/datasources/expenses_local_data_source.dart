import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_local_database.dart';
import '../../../dashboard/domain/entities/account_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_form_data_entity.dart';
import '../../domain/entities/expense_item_entity.dart';

final expensesLocalDataSourceProvider = Provider<ExpensesLocalDataSource>((ref) {
  return ExpensesLocalDataSource();
});

class ExpensesLocalDataSource {
  Future<bool> createExpenseLocally({
    required int idLugar,
    required String fecha,
    required String conceptoGeneral,
    required List<ExpenseItemEntity> items,
  }) async {
    final db = await AppLocalDatabase.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final encSyncId = AppLocalDatabase.generateUuid();

    await db.transaction((txn) async {
      await txn.insert('movimiento_enc_local', {
        'sync_id': encSyncId,
        'remote_id': null,
        'tipo_movimiento': 2,
        'concepto_general': conceptoGeneral,
        'fecha_movimiento': fecha,
        'sync_status': 'pending_create',
        'created_at': now,
        'updated_at': now,
      });

      for (final item in items) {
        final detSyncId = AppLocalDatabase.generateUuid();
        await txn.insert('movimiento_det_local', {
          'sync_id': detSyncId,
          'remote_id': null,
          'movimiento_enc_sync_id': encSyncId,
          'lugar_sync_id': 'lug_remote_$idLugar',
          'lugar_remote_id': idLugar,
          'categoria_sync_id': 'cat_remote_${item.idCategoria}',
          'categoria_remote_id': item.idCategoria,
          'concepto': item.concepto,
          'monto': -item.monto.abs(),
          'sync_status': 'pending_create',
          'created_at': now,
          'updated_at': now,
        });
      }

      final totalMonto = items.fold(0.0, (acc, it) => acc + it.monto.abs());
      await txn.rawUpdate(
        'UPDATE lugares_local SET saldo_actual = saldo_actual - ? WHERE remote_id = ? OR id = ?',
        [totalMonto, idLugar, idLugar],
      );
    });

    if (kDebugMode) {
      debugPrint('[SYNC-DEBUG] [WRITE] Tabla: movimiento_enc_local & det_local | Gasto creado en SQLite local');
    }

    return true;
  }

  Future<int?> suggestCategoryLocally(String concepto) async {
    final db = await AppLocalDatabase.instance;
    final trimmed = concepto.trim();
    if (trimmed.length < 3) return null;

    final List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT categoria_remote_id FROM movimiento_det_local WHERE concepto LIKE ? AND categoria_remote_id IS NOT NULL ORDER BY id DESC LIMIT 1',
      ['%$trimmed%'],
    );

    if (kDebugMode) {
      debugPrint('[SYNC-DEBUG] [READ] Tabla: movimiento_det_local | Sugerencia categoría | Filas devueltas: ${res.length}');
    }

    if (res.isNotEmpty && res.first['categoria_remote_id'] != null) {
      return res.first['categoria_remote_id'] as int;
    }
    return null;
  }

  Future<ExpenseFormDataEntity> getFormDataLocally() async {
    final db = await AppLocalDatabase.instance;

    final List<Map<String, dynamic>> lugaresMaps = await db.query(
      'lugares_local',
      where: "estado = 1 AND sync_status != 'pending_delete'",
      orderBy: 'nombre ASC',
    );

    final List<Map<String, dynamic>> categoriasMaps = await db.query(
      'categorias_local',
      where: "estado = 1 AND sync_status != 'pending_delete'",
      orderBy: 'nombre ASC',
    );

    final List<Map<String, dynamic>> conceptosMaps = await db.rawQuery(
      "SELECT DISTINCT concepto FROM movimiento_det_local WHERE concepto IS NOT NULL AND concepto != '' ORDER BY concepto ASC LIMIT 50",
    );

    if (kDebugMode) {
      debugPrint('[SYNC-DEBUG] [READ] Tabla: lugares_local & categorias_local | Origen: sqlite | Cuentas: ${lugaresMaps.length}, Cats: ${categoriasMaps.length}');
    }

    final lugares = lugaresMaps.map((m) {
      final id = m['remote_id'] as int? ?? m['id'] as int;
      final nom = m['nombre'] as String;
      final tipoMon = m['tipo_moneda'] as int? ?? 1;
      final saldo = (m['saldo_actual'] as num?)?.toDouble() ?? 0.0;
      return AccountEntity(
        idLugar: id,
        nombre: nom,
        tipoMoneda: tipoMon,
        simboloMoneda: tipoMon == 2 ? 'US\$' : '\$',
        montoOriginal: saldo,
        montoPesos: tipoMon == 2 ? saldo * 1000 : saldo,
        cotizacion: tipoMon == 2 ? 1000.0 : 1.0,
      );
    }).toList();

    final categorias = categoriasMaps.map((m) {
      final id = m['remote_id'] as int? ?? m['id'] as int;
      final nom = m['nombre'] as String;
      return CategoryEntity(
        idCategoria: id,
        nombre: nom,
      );
    }).toList();

    final conceptos = conceptosMaps.map((m) => m['concepto'] as String).toList();

    return ExpenseFormDataEntity(
      lugares: lugares,
      categorias: categorias,
      conceptos: conceptos,
    );
  }
}
