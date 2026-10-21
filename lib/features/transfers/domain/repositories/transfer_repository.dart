import 'package:gastos_mobile/features/dashboard/domain/entities/account_entity.dart';

abstract class TransferRepository {
  Future<List<AccountEntity>> getLugares();
  Future<bool> createTransfer({
    required int idOrigen,
    required int idDestino,
    required double monto,
    required String concepto,
    required String fecha,
  });
}
