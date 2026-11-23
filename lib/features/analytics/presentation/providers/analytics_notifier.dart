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

  /// Cada pestaña consulta la primera vez que se abre; después muestra lo ya cargado (↻ vuelve a consultar).
  Future<void> cambiarTab(int tabIndex) async {
    state = state.copyWith(activeTab: tabIndex);
    final (cargada, cargar) = switch (tabIndex) {
      0 => (state.categoryReport != null, cargarReporteCategorias),
      1 => (state.monthlyReport != null, cargarComparativaMensual),
      2 => (state.dailyReport != null, cargarEvolucionDiaria),
      _ => (state.productosPrecios.isNotEmpty, cargarPreciosProductos),
    };
    if (!cargada) await cargar();
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
        );
        if (mounted) state = state.copyWith(categoryReport: report);
      });

  Future<void> cambiarPeriodo(String periodo) {
    final (desde, hasta) = rangoDe(periodo, DateTime.now());
    state = state.copyWith(selectedPeriodo: periodo, desde: desde, hasta: hasta);
    return cargarReporteCategorias();
  }

  /// Primer y último día de 'mes_anterior', 'anio_actual' o (cualquier otro) el mes de [now].
  @visibleForTesting
  static (DateTime, DateTime) rangoDe(String periodo, DateTime now) => switch (periodo) {
        'mes_anterior' => (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
        'anio_actual' => (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
        _ => (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
      };

  Future<void> cambiarRangoFechas(DateTime desde, DateTime hasta) {
    state = state.copyWith(selectedPeriodo: 'personalizado', desde: desde, hasta: hasta);
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

  Future<void> cargarPreciosProductos({String? search}) {
    state = state.copyWith(isLoadingPrecios: true, busquedaPrecios: search ?? state.busquedaPrecios, clearError: true);
    return _run('catálogo de precios', () async {
      final list = await _repository.getProducts(search: state.busquedaPrecios);
      if (mounted) state = state.copyWith(isLoadingPrecios: false, productosPrecios: list);
    }, usesStatus: false);
  }

  Future<void> buscarPrecios(String query) => cargarPreciosProductos(search: query);
}
