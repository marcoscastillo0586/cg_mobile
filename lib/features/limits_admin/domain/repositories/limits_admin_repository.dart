import '../entities/expense_limit_admin_entity.dart';

abstract class LimitsAdminRepository {
  /// Obtiene todos los presupuestos / límites de gasto con cálculos en tiempo real
  Future<List<ExpenseLimitAdminEntity>> getLimits();

  /// Crea un nuevo límite de gasto
  Future<ExpenseLimitAdminEntity> createLimit({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  });

  /// Modifica el monto límite u otros parámetros de un tope existente
  Future<bool> updateLimit({
    required int idLimiteGasto,
    required double montoLimite,
    DateTime? desde,
    DateTime? hasta,
    List<int>? categoriasIds,
    List<int>? lugaresIds,
  });

  /// Renueva el período del límite por 1 mes adicional
  Future<bool> renewLimit({
    required int idLimiteGasto,
  });

  /// Elimina permanentemente el límite de gasto
  Future<bool> deleteLimit({
    required int idLimiteGasto,
  });
}
