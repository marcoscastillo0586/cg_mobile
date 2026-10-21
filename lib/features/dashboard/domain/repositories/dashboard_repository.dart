import '../entities/dashboard_summary_entity.dart';
import '../entities/expense_limit_entity.dart';

abstract class DashboardRepository {
  Future<DashboardSummaryEntity> getSaldos({String? hasta});
  Future<List<ExpenseLimitEntity>> getLimites();
}
