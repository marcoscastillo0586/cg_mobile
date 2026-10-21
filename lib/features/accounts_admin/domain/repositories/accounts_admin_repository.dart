import '../entities/account_admin_entity.dart';

abstract class AccountsAdminRepository {
  /// Obtiene todas las cuentas (activas e inactivas)
  Future<List<AccountAdminEntity>> getAccounts({bool todos = true});

  /// Crea una nueva cuenta
  Future<AccountAdminEntity> createAccount({
    required String nombre,
    required int tipoMoneda,
    String? img,
  });

  /// Actualiza una cuenta existente
  Future<AccountAdminEntity> updateAccount({
    required int idLugar,
    required String nombre,
    required int tipoMoneda,
    required bool activo,
  });

  /// Activa o desactiva una cuenta
  Future<bool> toggleAccountStatus({
    required int idLugar,
    required bool activo,
  });

  /// Elimina una cuenta físicamente o la desactiva si tiene movimientos
  Future<({bool eliminadoFisico, bool desactivado, String mensaje})> deleteAccount({
    required int idLugar,
  });
}
