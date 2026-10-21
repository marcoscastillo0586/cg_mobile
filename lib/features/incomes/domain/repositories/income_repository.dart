import 'package:gastos_mobile/features/dashboard/domain/entities/account_entity.dart';

abstract class IncomeRepository {
  Future<List<AccountEntity>> getLugares();
  Future<bool> createIncome({
    required int idLugar,
    required double monto,
    required String concepto,
    required String fecha,
  });
}
