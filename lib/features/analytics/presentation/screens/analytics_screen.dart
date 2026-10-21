import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/analytics_notifier.dart';
import '../providers/analytics_state.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/daily_line_chart.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/product_price_tracker_view.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        AppFeedback.selection();
        ref.read(analyticsNotifierProvider.notifier).cambiarTab(_tabController.index);
      }
    });

    Future.microtask(() {
      ref.read(analyticsNotifierProvider.notifier).inicializar();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _seleccionarRangoPersonalizado() async {
    final state = ref.read(analyticsNotifierProvider);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: state.desde, end: state.hasta),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecciona rango para el reporte',
    );
    if (picked != null) {
      AppFeedback.selection();
      await ref
          .read(analyticsNotifierProvider.notifier)
          .cambiarRangoFechas(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(analyticsNotifierProvider);
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Analíticas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar reporte',
            onPressed: () {
              AppFeedback.selection();
              if (state.activeTab == 0) {
                ref.read(analyticsNotifierProvider.notifier).cargarReporteCategorias();
              } else if (state.activeTab == 1) {
                ref.read(analyticsNotifierProvider.notifier).cargarComparativaMensual();
              } else if (state.activeTab == 2) {
                ref.read(analyticsNotifierProvider.notifier).cargarEvolucionDiaria();
              } else {
                ref.read(analyticsNotifierProvider.notifier).cargarPreciosProductos();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Categorías', icon: Icon(Icons.pie_chart_rounded, size: 18)),
            Tab(text: 'Comparativa', icon: Icon(Icons.bar_chart_rounded, size: 18)),
            Tab(text: 'Día a Día', icon: Icon(Icons.show_chart_rounded, size: 18)),
            Tab(text: 'Precios', icon: Icon(Icons.sell_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabCategorias(state, isDark, theme, currencyFormat),
          _buildTabComparativa(state, isDark, theme, currencyFormat),
          _buildTabEvolucionDiaria(state, isDark, theme, currencyFormat),
          const ProductPriceTrackerView(),
        ],
      ),
    );
  }


  // -------------------------------------------------------------
  // TAB 1: GASTOS POR CATEGORÍA
  // -------------------------------------------------------------
  Widget _buildTabCategorias(
    AnalyticsState state,
    bool isDark,
    ThemeData theme,
    NumberFormat currencyFormat,
  ) {
    final report = state.categoryReport;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(analyticsNotifierProvider.notifier).cargarReporteCategorias();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector de Período
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChoiceChip('mes_actual', 'Este Mes', state),
                const SizedBox(width: 8),
                _buildPeriodChoiceChip('mes_anterior', 'Mes Anterior', state),
                const SizedBox(width: 8),
                _buildPeriodChoiceChip('anio_actual', 'Año Actual', state),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 14),
                  label: Text(
                    state.selectedPeriodo == 'personalizado'
                        ? '${dateFormat.format(state.desde)} - ${dateFormat.format(state.hasta)}'
                        : 'Personalizado',
                  ),
                  onPressed: _seleccionarRangoPersonalizado,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (state.status == AnalyticsStatus.loading && report == null)
            _buildLoadingSkeleton()
          else if (report != null) ...[
            // Tarjeta Donut Chart
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CategoryPieChart(report: report),
              ),
            ),
            const SizedBox(height: 16),

            // Top Conceptos / Subcategorías más frecuentes
            if (report.subcategorias.isNotEmpty) ...[
              Text(
                'Detalle de Conceptos Frecuentes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: isDark ? 0 : 1,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: report.subcategorias.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final sub = report.subcategorias[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        sub.concepto,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${sub.categoria} • ${sub.cantidad} comp.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(sub.monto),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${sub.porcentaje.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChoiceChip(String key, String label, AnalyticsState state) {
    final isSelected = state.selectedPeriodo == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
      onSelected: (_) {
        AppFeedback.selection();
        ref.read(analyticsNotifierProvider.notifier).cambiarPeriodo(key);
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 2: COMPARATIVA ANUAL (INGRESOS VS EGRESOS)
  // -------------------------------------------------------------
  Widget _buildTabComparativa(
    AnalyticsState state,
    bool isDark,
    ThemeData theme,
    NumberFormat currencyFormat,
  ) {
    final report = state.monthlyReport;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(analyticsNotifierProvider.notifier).cargarComparativaMensual();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector de Año
          if (report != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ejercicio Anual',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: state.selectedAnio,
                      isDense: true,
                      items: report.aniosDisponibles.map((a) {
                        return DropdownMenuItem<int>(
                          value: a,
                          child: Text(
                            '$a',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          AppFeedback.selection();
                          ref.read(analyticsNotifierProvider.notifier).cargarComparativaMensual(anio: val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),

          if (state.status == AnalyticsStatus.loading && report == null)
            _buildLoadingSkeleton()
          else if (report != null) ...[
            // 4 KPIs Financieros
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Ingresos Anuales',
                    value: currencyFormat.format(report.totalesAnuales.totalIngresos),
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.emerald,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Egresos Anuales',
                    value: currencyFormat.format(report.totalesAnuales.totalEgresos),
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.rose,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Balance Neto',
                    value: currencyFormat.format(report.totalesAnuales.balanceNeto),
                    icon: Icons.savings_outlined,
                    color: report.totalesAnuales.balanceNeto >= 0 ? AppColors.emerald : AppColors.rose,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Tasa de Ahorro',
                    value: '${report.totalesAnuales.tasaAhorroPorcentaje.toStringAsFixed(1)}%',
                    icon: Icons.percent_rounded,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gráfico de Barras Agrupadas
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresos vs Egresos Mes a Mes',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    MonthlyBarChart(report: report),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabla Resumen Mensual
            Text(
              'Desglose Mensual Detallado',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: isDark ? 0 : 1,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: report.meses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final m = report.meses[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      m.nombreMes,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          'Ing: ${currencyFormat.format(m.ingresos)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.emerald),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Egr: ${currencyFormat.format(m.egresos)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.rose),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(m.balance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: m.esSuperavit ? AppColors.emerald : AppColors.rose,
                          ),
                        ),
                        Text(
                          m.esSuperavit ? 'Superávit' : 'Déficit',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: m.esSuperavit ? AppColors.emerald : AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: EVOLUCIÓN DÍA A DÍA
  // -------------------------------------------------------------
  Widget _buildTabEvolucionDiaria(
    AnalyticsState state,
    bool isDark,
    ThemeData theme,
    NumberFormat currencyFormat,
  ) {
    final report = state.dailyReport;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(analyticsNotifierProvider.notifier).cargarEvolucionDiaria();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector de Mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Curva de Gasto Diario',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: state.selectedMesDiario,
                  isDense: true,
                  items: List.generate(12, (i) {
                    final mesNum = i + 1;
                    final nombre = DateFormat('MMMM', 'es_AR').format(DateTime(2026, mesNum));
                    return DropdownMenuItem<int>(
                      value: mesNum,
                      child: Text(
                        nombre[0].toUpperCase() + nombre.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      AppFeedback.selection();
                      ref.read(analyticsNotifierProvider.notifier).cargarEvolucionDiaria(mes: val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (state.status == AnalyticsStatus.loading && report == null)
            _buildLoadingSkeleton()
          else if (report != null) ...[
            // Métricas rápidas del mes
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total del Mes',
                    value: currencyFormat.format(report.totalEgresosMes),
                    icon: Icons.payments_outlined,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Pico Más Alto',
                    value: currencyFormat.format(report.maximoGastoDiario),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.rose,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gráfico de Líneas con Curvas Suaves
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trayectoria Diaria de Egresos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    DailyLineChart(report: report),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerEffect(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
