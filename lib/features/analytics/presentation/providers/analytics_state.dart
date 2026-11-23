import 'package:equatable/equatable.dart';
import '../../domain/entities/category_expense_report_entity.dart';
import '../../domain/entities/daily_evolution_entity.dart';
import '../../domain/entities/monthly_comparison_entity.dart';
import '../../domain/entities/product_price_entity.dart';

enum AnalyticsStatus { initial, loading, loaded, error }

class AnalyticsState extends Equatable {
  final AnalyticsStatus status;
  final int activeTab; // 0 = Categorías, 1 = Comparativa Anual, 2 = Evolución Diaria, 3 = Precios e Inflación
  /// Error de la última consulta (se traduce en la UI por su code).
  final Object? error;

  // Tab 1: Categorías
  final CategoryExpenseReportEntity? categoryReport;
  final String selectedPeriodo; // 'mes_actual', 'mes_anterior', 'anio_actual', 'personalizado'
  final DateTime desde;
  final DateTime hasta;

  // Tab 2: Comparativa Anual
  final MonthlyComparisonReportEntity? monthlyReport;
  final int selectedAnio;

  // Tab 3: Evolución Diaria
  final DailyEvolutionReportEntity? dailyReport;
  final int selectedMesDiario;
  final int selectedAnioDiario;

  // Tab 4: Precios e Inflación (Price Tracker)
  final List<ProductPriceItemEntity> productosPrecios;
  final String busquedaPrecios;
  final bool isLoadingPrecios;

  const AnalyticsState({
    required this.status,
    required this.activeTab,
    this.error,
    this.categoryReport,
    required this.selectedPeriodo,
    required this.desde,
    required this.hasta,
    this.monthlyReport,
    required this.selectedAnio,
    this.dailyReport,
    required this.selectedMesDiario,
    required this.selectedAnioDiario,
    this.productosPrecios = const [],
    this.busquedaPrecios = '',
    this.isLoadingPrecios = false,
  });

  factory AnalyticsState.initial() {
    final now = DateTime.now();
    return AnalyticsState(
      status: AnalyticsStatus.initial,
      activeTab: 0,
      selectedPeriodo: 'mes_actual',
      desde: DateTime(now.year, now.month, 1),
      hasta: DateTime(now.year, now.month + 1, 0),
      selectedAnio: now.year,
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
    Object? error,
    CategoryExpenseReportEntity? categoryReport,
    String? selectedPeriodo,
    DateTime? desde,
    DateTime? hasta,
    MonthlyComparisonReportEntity? monthlyReport,
    int? selectedAnio,
    DailyEvolutionReportEntity? dailyReport,
    int? selectedMesDiario,
    int? selectedAnioDiario,
    List<ProductPriceItemEntity>? productosPrecios,
    String? busquedaPrecios,
    bool? isLoadingPrecios,
    bool clearError = false,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      activeTab: activeTab ?? this.activeTab,
      error: clearError ? null : (error ?? this.error),
      categoryReport: categoryReport ?? this.categoryReport,
      selectedPeriodo: selectedPeriodo ?? this.selectedPeriodo,
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      monthlyReport: monthlyReport ?? this.monthlyReport,
      selectedAnio: selectedAnio ?? this.selectedAnio,
      dailyReport: dailyReport ?? this.dailyReport,
      selectedMesDiario: selectedMesDiario ?? this.selectedMesDiario,
      selectedAnioDiario: selectedAnioDiario ?? this.selectedAnioDiario,
      productosPrecios: productosPrecios ?? this.productosPrecios,
      busquedaPrecios: busquedaPrecios ?? this.busquedaPrecios,
      isLoadingPrecios: isLoadingPrecios ?? this.isLoadingPrecios,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeTab,
        error,
        categoryReport,
        selectedPeriodo,
        desde,
        hasta,
        monthlyReport,
        selectedAnio,
        dailyReport,
        selectedMesDiario,
        selectedAnioDiario,
        productosPrecios,
        busquedaPrecios,
        isLoadingPrecios,
      ];
}

