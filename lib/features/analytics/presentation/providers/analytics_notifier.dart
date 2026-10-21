import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reports_repository.dart';
import 'analytics_state.dart';

final analyticsNotifierProvider = StateNotifierProvider.autoDispose<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref.watch(reportsRepositoryProvider));
});

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Reportes de la API. Solo lectura.
class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final ReportsRepository _repository;

  AnalyticsNotifier(this._repository) : super(AnalyticsState.initial());

  Future<void> inicializar() => cargarReporteCategorias();

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

  /// Ejecuta una consulta registrando y guardando el error (nunca lo descarta).
  Future<void> _run(String what, Future<void> Function() body, {bool usesStatus = true}) async {
    if (usesStatus) state = state.copyWith(status: AnalyticsStatus.loading, clearError: true);
    try {
      await body();
      if (usesStatus && mounted) state = state.copyWith(status: AnalyticsStatus.loaded);
    } catch (e) {
      debugPrint('[REPORTES] $what: $e');
      if (!mounted) return;
      state = state.copyWith(status: usesStatus ? AnalyticsStatus.error : null, error: e, isLoadingPrecios: false);
    }
  }

  Future<void> cargarReporteCategorias() => _run('por categoría', () async {
        final report = await _repository.getCategoryReport(
          from: _iso(state.desde),
          to: _iso(state.hasta),
          accountIds: state.idLugarFiltro == null ? const [] : [state.idLugarFiltro!],
        );
        if (mounted) state = state.copyWith(categoryReport: report);
      });

  Future<void> cambiarPeriodo(String periodo) {
    final now = DateTime.now();
    late DateTime desde;
    late DateTime hasta;
    switch (periodo) {
      case 'mes_anterior':
        desde = DateTime(now.year, now.month - 1, 1);
        hasta = DateTime(now.year, now.month, 0);
      case 'anio_actual':
        desde = DateTime(now.year, 1, 1);
        hasta = DateTime(now.year, 12, 31);
      default:
        desde = DateTime(now.year, now.month, 1);
        hasta = DateTime(now.year, now.month + 1, 0);
    }
    state = state.copyWith(selectedPeriodo: periodo, desde: desde, hasta: hasta);
    return cargarReporteCategorias();
  }

  Future<void> cambiarRangoFechas(DateTime desde, DateTime hasta) {
    state = state.copyWith(selectedPeriodo: 'personalizado', desde: desde, hasta: hasta);
    return cargarReporteCategorias();
  }

  Future<void> cambiarLugarFiltro(int? idLugar) {
    state = state.copyWith(idLugarFiltro: idLugar);
    return cargarReporteCategorias();
  }

  Future<void> cargarComparativaMensual({int? anio}) {
    final target = anio ?? state.selectedAnio;
    state = state.copyWith(selectedAnio: target);
    return _run('comparativa anual', () async {
      final report = await _repository.getIncomeExpense(year: target);
      if (mounted) state = state.copyWith(monthlyReport: report);
    });
  }

  Future<void> cargarEvolucionDiaria({int? mes, int? anio}) {
    final m = mes ?? state.selectedMesDiario;
    final a = anio ?? state.selectedAnioDiario;
    state = state.copyWith(selectedMesDiario: m, selectedAnioDiario: a);
    return _run('evolución diaria', () async {
      final report = await _repository.getDaily(year: a, month: m);
      if (mounted) state = state.copyWith(dailyReport: report);
    });
  }

  void setTouchedPieIndex(int index) => state = state.copyWith(touchedPieIndex: index);

  void setTouchedBarGroupIndex(int index) => state = state.copyWith(touchedBarGroupIndex: index);

  Future<void> cargarPreciosProductos({String? search}) {
    state = state.copyWith(isLoadingPrecios: true, busquedaPrecios: search ?? state.busquedaPrecios, clearError: true);
    return _run('catálogo de precios', () async {
      final list = await _repository.getProducts(search: state.busquedaPrecios);
      if (mounted) state = state.copyWith(isLoadingPrecios: false, productosPrecios: list);
    }, usesStatus: false);
  }

  Future<void> buscarPrecios(String query) => cargarPreciosProductos(search: query);

  Future<void> cargarHistorialProducto(String concepto, {String? plu}) {
    return _run('historial de producto', () async {
      final history = await _repository.getProductHistory(concept: plu == null ? concepto : null, plu: plu);
      if (mounted) state = state.copyWith(productoSeleccionadoHistorial: history);
    }, usesStatus: false);
  }

  Future<void> ejecutarComparativaPrecios({
    required String desde1,
    required String hasta1,
    required String desde2,
    required String hasta2,
  }) {
    state = state.copyWith(isLoadingPrecios: true, clearError: true);
    return _run('comparativa de precios', () async {
      final res = await _repository.compareProducts(from1: desde1, to1: hasta1, from2: desde2, to2: hasta2);
      if (mounted) state = state.copyWith(isLoadingPrecios: false, comparativaPrecios: res);
    }, usesStatus: false);
  }
}
