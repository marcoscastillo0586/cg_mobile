import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/expense_form_data_entity.dart';
import '../../domain/entities/expense_item_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_data_source.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.watch(expenseRemoteDataSourceProvider));
});

/// Formulario de egreso (contrato PHP viejo hasta la etapa 5). Sin respaldo local: los
/// errores llegan a la pantalla.
class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDataSource _remoteDataSource;

  ExpenseRepositoryImpl(this._remoteDataSource);

  @override
  Future<ExpenseFormDataEntity> getFormData() => _remoteDataSource.getFormData();

  @override
  Future<bool> createExpense({
    required int idLugar,
    required String fecha,
    required String conceptoGeneral,
    required List<ExpenseItemEntity> items,
  }) async {
    // Las escrituras pasan por SQLite y la cola de sincronización (etapa 5). Hasta entonces
    // se informa, en lugar de simular un éxito.
    throw const ServerFailure('Función no disponible por ahora', null, 'NOT_AVAILABLE');
  }

  /// La sugerencia es opcional: si falla, no se sugiere nada y el motivo queda registrado.
  @override
  Future<int?> suggestCategory(String concepto) async {
    try {
      return await _remoteDataSource.suggestCategory(concepto);
    } catch (e) {
      debugPrint('[EGRESO] Sin sugerencia de categoría: $e');
      return null;
    }
  }
}
