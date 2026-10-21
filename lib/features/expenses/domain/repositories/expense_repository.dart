import '../entities/expense_form_data_entity.dart';
import '../entities/expense_item_entity.dart';

abstract class ExpenseRepository {
  Future<ExpenseFormDataEntity> getFormData();
  Future<bool> createExpense({
    required int idLugar,
    required String fecha,
    required String conceptoGeneral,
    required List<ExpenseItemEntity> items,
  });
  Future<int?> suggestCategory(String concepto);
}
