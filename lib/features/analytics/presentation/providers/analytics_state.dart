import 'package:equatable/equatable.dart';
import '../../domain/entities/category_expense_report_entity.dart';
import '../../domain/entities/daily_evolution_entity.dart';
import '../../domain/entities/monthly_comparison_entity.dart';
import '../../domain/entities/product_price_entity.dart';

enum AnalyticsStatus { initial, loading, loaded, error }

class AnalyticsState extends Equatable {
  final AnalyticsStatus status;
  final int activeTab; // 0 = Categorías, 1 = Comparativa Anual, 2 = Evolución Diaria, 3 = Precios e Inflación
  final String? errorMessage;

  // Tab 1: Categorías
  final CategoryExpenseReportEntity? categoryReport;
  final String selectedPeriodo; // 'mes_actual', 'mes_anterior', 'anio_actual', 'personalizado'
  final DateTime desde;
  final DateTime hasta;
  final int? idLugarFiltro;
  final int touchedPieIndex;

  // Tab 2: Comparativa Anual
  final MonthlyComparisonReportEntity? monthlyReport;
  final int selectedAnio;
  final int touchedBarGroupIndex;

  // Tab 3: Evolución Diaria
  final DailyEvolutionReportEntity? dailyReport;
  final int selectedMesDiario;
  final int selectedAnioDiario;

  // Tab 4: Precios e Inflación (Price Tracker)
  final List<ProductPriceItemEntity> productosPrecios;
  final String busquedaPrecios;
  final bool isLoadingPrecios;
  final ProductPriceHistoryEntity? productoSeleccionadoHistorial;
  final PriceComparisonResultEntity? comparativaPrecios;

  const AnalyticsState({
    required this.status,
    required this.activeTab,
    this.errorMessage,
    this.categoryReport,
    required this.selectedPeriodo,
    required this.desde,
    required this.hasta,
    this.idLugarFiltro,
    required this.touchedPieIndex,
    this.monthlyReport,
    required this.selectedAnio,
    required this.touchedBarGroupIndex,
    this.dailyReport,
    required this.selectedMesDiario,
    required this.selectedAnioDiario,
    this.productosPrecios = const [],
    this.busquedaPrecios = '',
    this.isLoadingPrecios = false,
    this.productoSeleccionadoHistorial,
    this.comparativaPrecios,
  });

  factory AnalyticsState.initial() {
    final now = DateTime.now();
    return AnalyticsState(
      status: AnalyticsStatus.initial,
      activeTab: 0,
      selectedPeriodo: 'mes_actual',
      desde: DateTime(now.year, now.month, 1),
      hasta: DateTime(now.year, now.month + 1, 0),
      idLugarFiltro: null,
      touchedPieIndex: -1,
      selectedAnio: now.year,
      touchedBarGroupIndex: -1,
      selectedMesDiario: now.month,
      selectedAnioDiario: now.year,
      productosPrecios: const [],
      busquedaPrecios: '',
      isLoadingPrecios: false,
    );
  }

  AnalyticsState copyWith({
    AnalyticsStatus? status,
    int? activeTab,
    String? errorMessage,
    CategoryExpenseReportEntity? categoryReport,
    String? selectedPeriodo,
    DateTime? desde,
    DateTime? hasta,
    int? idLugarFiltro,
    int? touchedPieIndex,
    MonthlyComparisonReportEntity? monthlyReport,
    int? selectedAnio,
    int? touchedBarGroupIndex,
    DailyEvolutionReportEntity? dailyReport,
    int? selectedMesDiario,
    int? selectedAnioDiario,
    List<ProductPriceItemEntity>? productosPrecios,
    String? busquedaPrecios,
    bool? isLoadingPrecios,
    ProductPriceHistoryEntity? productoSeleccionadoHistorial,
    PriceComparisonResultEntity? comparativaPrecios,
    bool clearError = false,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      activeTab: activeTab ?? this.activeTab,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      categoryReport: categoryReport ?? this.categoryReport,
      selectedPeriodo: selectedPeriodo ?? this.selectedPeriodo,
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      idLugarFiltro: idLugarFiltro ?? this.idLugarFiltro,
      touchedPieIndex: touchedPieIndex ?? this.touchedPieIndex,
      monthlyReport: monthlyReport ?? this.monthlyReport,
      selectedAnio: selectedAnio ?? this.selectedAnio,
      touchedBarGroupIndex: touchedBarGroupIndex ?? this.touchedBarGroupIndex,
      dailyReport: dailyReport ?? this.dailyReport,
      selectedMesDiario: selectedMesDiario ?? this.selectedMesDiario,
      selectedAnioDiario: selectedAnioDiario ?? this.selectedAnioDiario,
      productosPrecios: productosPrecios ?? this.productosPrecios,
      busquedaPrecios: busquedaPrecios ?? this.busquedaPrecios,
      isLoadingPrecios: isLoadingPrecios ?? this.isLoadingPrecios,
      productoSeleccionadoHistorial: productoSeleccionadoHistorial ?? this.productoSeleccionadoHistorial,
      comparativaPrecios: comparativaPrecios ?? this.comparativaPrecios,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeTab,
        errorMessage,
        categoryReport,
        selectedPeriodo,
        desde,
        hasta,
        idLugarFiltro,
        touchedPieIndex,
        monthlyReport,
        selectedAnio,
        touchedBarGroupIndex,
        dailyReport,
        selectedMesDiario,
        selectedAnioDiario,
        productosPrecios,
        busquedaPrecios,
        isLoadingPrecios,
        productoSeleccionadoHistorial,
        comparativaPrecios,
      ];
}

