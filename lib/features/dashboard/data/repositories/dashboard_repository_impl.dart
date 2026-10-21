import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../accounts_admin/data/datasources/accounts_local_data_source.dart';
import '../../../limits_admin/data/datasources/limits_local_data_source.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/dashboard_summary_entity.dart';
import '../../domain/entities/expense_limit_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final remoteDataSource = ref.watch(dashboardRemoteDataSourceProvider);
  final accountsLocalDataSource = ref.watch(accountsLocalDataSourceProvider);
  final limitsLocalDataSource = ref.watch(limitsLocalDataSourceProvider);
  return DashboardRepositoryImpl(remoteDataSource, accountsLocalDataSource, limitsLocalDataSource);
});

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remoteDataSource;
  final AccountsLocalDataSource _accountsLocalDataSource;
  final LimitsLocalDataSource _limitsLocalDataSource;

  DashboardRepositoryImpl(
    this._remoteDataSource,
    this._accountsLocalDataSource,
    this._limitsLocalDataSource,
  );

  @override
  Future<DashboardSummaryEntity> getSaldos({String? hasta}) async {
    try {
      final remoteSummary = await _remoteDataSource.getSaldos(hasta: hasta);
      // Filtrar cuentas con saldo cero por defecto para la vista principal
      final cuentasFiltradas = remoteSummary.cuentas
          .where((c) => c.montoOriginal != 0.0)
          .toList();

      return DashboardSummaryEntity(
        sumaTotalPesos: remoteSummary.sumaTotalPesos,
        cotizacionNombre: remoteSummary.cotizacionNombre,
        cotizacionDolar: remoteSummary.cotizacionDolar,
        fechaFiltro: remoteSummary.fechaFiltro,
        cuentas: cuentasFiltradas.isNotEmpty ? cuentasFiltradas : remoteSummary.cuentas,
      );
    } catch (_) {
      // Fallback 100% Offline-First leyendo de SQLite local (filtrando cuentas con saldo cero)
      final localAccountsAdmin = await _accountsLocalDataSource.getAccounts(
        todos: false,
        ocultarSaldoCero: true,
      );

      final List<AccountEntity> cuentasLocal = localAccountsAdmin.map((acc) {
        return AccountEntity(
          idLugar: acc.idLugar,
          nombre: acc.nombre,
          tipoMoneda: acc.tipoMoneda,
          simboloMoneda: acc.monedaSimbolo,
          montoOriginal: acc.saldoActual,
          montoPesos: acc.esUsd ? acc.saldoActual * 1000 : acc.saldoActual,
          cotizacion: acc.esUsd ? 1000.0 : 1.0,
        );
      }).toList();

      final double totalArs = cuentasLocal
          .where((c) => !c.isUSD)
          .fold(0.0, (sum, c) => sum + c.montoOriginal);
      final double totalUsd = cuentasLocal
          .where((c) => c.isUSD)
          .fold(0.0, (sum, c) => sum + c.montoOriginal);

      return DashboardSummaryEntity(
        sumaTotalPesos: totalArs + (totalUsd * 1000.0),
        cotizacionNombre: 'Dólar Oficial (Offline)',
        cotizacionDolar: 1000.0,
        cuentas: cuentasLocal,
      );
    }
  }

  @override
  Future<List<ExpenseLimitEntity>> getLimites() async {
    try {
      return await _remoteDataSource.getLimites();
    } catch (_) {
      final localLimitsAdmin = await _limitsLocalDataSource.getLimits();
      return localLimitsAdmin.map((lim) {
        return ExpenseLimitEntity(
          idLimiteGasto: lim.idLimiteGasto,
          nombre: lim.categoriasNombres,
          categorias: lim.categoria,
          lugares: lim.lugar,
          montoLimite: lim.montoLimite,
          montoConsumido: lim.montoConsumido,
          resto: lim.resto,
          porcentaje: lim.porcentaje,
          vencido: lim.vencido,
        );
      }).toList();
    }
  }
}
