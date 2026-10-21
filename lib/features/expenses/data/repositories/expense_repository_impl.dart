import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense_form_data_entity.dart';
import '../../domain/entities/expense_item_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_data_source.dart';
import '../datasources/expenses_local_data_source.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final remoteDataSource = ref.watch(expenseRemoteDataSourceProvider);
  final localDataSource = ref.watch(expensesLocalDataSourceProvider);
  return ExpenseRepositoryImpl(remoteDataSource, localDataSource);
});

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDataSource _remoteDataSource;
  final ExpensesLocalDataSource _localDataSource;

  ExpenseRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<ExpenseFormDataEntity> getFormData() async {
    try {
      final remoteData = await _remoteDataSource.getFormData();
      return remoteData;
    } catch (_) {
      return await _localDataSource.getFormDataLocally();
    }
  }

  @override
  Future<bool> createExpense({
    required int idLugar,
    required String fecha,
    required String conceptoGeneral,
    required List<ExpenseItemEntity> items,
  }) async {
    // 1. Escribir inmediatamente en la base de datos local SQLite (Offline-first)
    await _localDataSource.createExpenseLocally(
      idLugar: idLugar,
      fecha: fecha,
      conceptoGeneral: conceptoGeneral,
      items: items,
    );

    // 2. Intentar sincronización con el servidor remoto si hay red
    try {
      await _remoteDataSource.createExpense(
        idLugar: idLugar,
        fecha: fecha,
        conceptoGeneral: conceptoGeneral,
        items: items,
      );
    } catch (_) {
      // Si no hay red, queda guardado en SQLite con sync_status = 'pending_create'
    }

    return true;
  }


  @override
  Future<int?> suggestCategory(String concepto) async {
    try {
      final remoteSuggest = await _remoteDataSource.suggestCategory(concepto);
      if (remoteSuggest != null) return remoteSuggest;
    } catch (_) {}
    return await _localDataSource.suggestCategoryLocally(concepto);
  }
}
