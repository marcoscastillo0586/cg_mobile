import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/repositories/analytics_repository.dart';
import 'analytics_state.dart';

final analyticsNotifierProvider =
    StateNotifierProvider.autoDispose<AnalyticsNotifier, AnalyticsState>((ref) {
  final repository = ref.watch(analyticsRepositoryProvider);
  return AnalyticsNotifier(repository);
});

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final AnalyticsRepository _repository;

  AnalyticsNotifier(this._repository) : super(AnalyticsState.initial());

  Future<void> inicializar() async {
    await cargarReporteCategorias();
  }

  Future<void> cambiarTab(int tabIndex) async {
    state = state.copyWith(activeTab: tabIndex);
    if (tabIndex == 0 && state.categoryReport == null) {
      await cargarReporteCategorias();
    } else if (tabIndex == 1 && state.monthlyReport == null) {
      await cargarComparativaMensual();
    } else if (tabIndex == 2 && state.dailyReport == null) {
      await cargarEvolucionDiaria();
    } else if (tabIndex == 3 && state.productosPrecios.isEmpty) {
      await cargarPreciosProductos();
    }
  }


  Future<void> cargarReporteCategorias() async {
    state = state.copyWith(status: AnalyticsStatus.loading, clearError: true);
    try {
      final report = await _repository.getCategoryExpenseReport(
        desde: state.desde,
        hasta: state.hasta,
        idLugar: state.idLugarFiltro,
      );
      state = state.copyWith(
        status: AnalyticsStatus.loaded,
        categoryReport: report,
      );
    } on Failure catch (e) {
      state = state.copyWith(status: AnalyticsStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsStatus.error,
        errorMessage: 'Error al consultar reporte por categoría: $e',
      );
    }
  }

  Future<void> cambiarPeriodo(String periodo) async {
    final now = DateTime.now();
    DateTime desde;
    DateTime hasta;

    switch (periodo) {
      case 'mes_anterior':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        desde = DateTime(prevMonth.year, prevMonth.month, 1);
        hasta = DateTime(prevMonth.year, prevMonth.month + 1, 0);
        break;
      case 'anio_actual':
        desde = DateTime(now.year, 1, 1);
        hasta = DateTime(now.year, 12, 31);
        break;
      case 'mes_actual':
      default:
        desde = DateTime(now.year, now.month, 1);
        hasta = DateTime(now.year, now.month + 1, 0);
        break;
    }

    state = state.copyWith(
      selectedPeriodo: periodo,
      desde: desde,
      hasta: hasta,
    );

    await cargarReporteCategorias();
  }

  Future<void> cambiarRangoFechas(DateTime desde, DateTime hasta) async {
    state = state.copyWith(
      selectedPeriodo: 'personalizado',
      desde: desde,
      hasta: hasta,
    );
    await cargarReporteCategorias();
  }

  Future<void> cambiarLugarFiltro(int? idLugar) async {
    state = state.copyWith(idLugarFiltro: idLugar);
    await cargarReporteCategorias();
  }

  Future<void> cargarComparativaMensual({int? anio}) async {
    final anioTarget = anio ?? state.selectedAnio;
    state = state.copyWith(
      status: AnalyticsStatus.loading,
      selectedAnio: anioTarget,
      clearError: true,
    );
    try {
      final report = await _repository.getMonthlyComparisonReport(anio: anioTarget);
      state = state.copyWith(
        status: AnalyticsStatus.loaded,
        monthlyReport: report,
      );
    } on Failure catch (e) {
      state = state.copyWith(status: AnalyticsStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsStatus.error,
        errorMessage: 'Error al consultar comparativa mensual: $e',
      );
    }
  }

  Future<void> cargarEvolucionDiaria({int? mes, int? anio}) async {
    final mesTarget = mes ?? state.selectedMesDiario;
    final anioTarget = anio ?? state.selectedAnioDiario;
    state = state.copyWith(
      status: AnalyticsStatus.loading,
      selectedMesDiario: mesTarget,
      selectedAnioDiario: anioTarget,
      clearError: true,
    );
    try {
      final report = await _repository.getDailyEvolutionReport(
        mes: mesTarget,
        anio: anioTarget,
      );
      state = state.copyWith(
        status: AnalyticsStatus.loaded,
        dailyReport: report,
      );
    } on Failure catch (e) {
      state = state.copyWith(status: AnalyticsStatus.error, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AnalyticsStatus.error,
        errorMessage: 'Error al consultar evolución diaria: $e',
      );
    }
  }

  void setTouchedPieIndex(int index) {
    state = state.copyWith(touchedPieIndex: index);
  }

  void setTouchedBarGroupIndex(int index) {
    state = state.copyWith(touchedBarGroupIndex: index);
  }

  Future<void> cargarPreciosProductos({String? search}) async {
    state = state.copyWith(
      isLoadingPrecios: true,
      busquedaPrecios: search ?? state.busquedaPrecios,
      clearError: true,
    );
    try {
      final list = await _repository.getProductPrices(search: search ?? state.busquedaPrecios);
      state = state.copyWith(
        isLoadingPrecios: false,
        productosPrecios: list,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoadingPrecios: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoadingPrecios: false,
        errorMessage: 'Error al consultar catálogo de precios: $e',
      );
    }
  }

  Future<void> buscarPrecios(String query) async {
    state = state.copyWith(busquedaPrecios: query);
    await cargarPreciosProductos(search: query);
  }

  Future<void> cargarHistorialProducto(String concepto) async {
    try {
      final history = await _repository.getProductPriceHistory(concepto);
      state = state.copyWith(productoSeleccionadoHistorial: history);
    } catch (_) {}
  }

  Future<void> ejecutarComparativaPrecios({
    required String desde1,
    required String hasta1,
    required String desde2,
    required String hasta2,
  }) async {
    state = state.copyWith(isLoadingPrecios: true, clearError: true);
    try {
      final res = await _repository.comparePrices(
        desde1: desde1,
        hasta1: hasta1,
        desde2: desde2,
        hasta2: hasta2,
      );
      state = state.copyWith(
        isLoadingPrecios: false,
        comparativaPrecios: res,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoadingPrecios: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoadingPrecios: false,
        errorMessage: 'Error al calcular comparativa de precios: $e',
      );
    }
  }
}

