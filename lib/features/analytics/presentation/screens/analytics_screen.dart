import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/entities/category_expense_report_entity.dart';
import '../../domain/entities/monthly_comparison_entity.dart';
import '../providers/analytics_notifier.dart';
import '../providers/analytics_state.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/daily_line_chart.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/product_price_tracker_view.dart';
import '../../../../l10n/l10n.dart';
import '../report_currency.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  AnalyticsNotifier get _notifier => ref.read(analyticsNotifierProvider.notifier);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      AppFeedback.selection();
      _notifier.cambiarTab(_tabController.index);
    });
    Future.microtask(() => _notifier.inicializar());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ↻: vuelve a consultar la pestaña visible.
  void _actualizar(int tab) {
    AppFeedback.selection();
    switch (tab) {
      case 0:
        _notifier.cargarReporteCategorias();
      case 1:
        _notifier.cargarComparativaMensual();
      case 2:
        _notifier.cargarEvolucionDiaria();
      default:
        _notifier.cargarPreciosProductos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tab = ref.watch(analyticsNotifierProvider.select((s) => s.activeTab));
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsAnalytics),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: l10n.refreshReport, onPressed: () => _actualizar(tab)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: l10n.categories2, icon: const Icon(Icons.pie_chart_rounded, size: 18)),
            Tab(text: l10n.comparison, icon: const Icon(Icons.bar_chart_rounded, size: 18)),
            Tab(text: l10n.dayDay, icon: const Icon(Icons.show_chart_rounded, size: 18)),
            Tab(text: l10n.prices, icon: const Icon(Icons.sell_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TabCategorias(), _TabComparativa(), _TabDiaria(), ProductPriceTrackerView()],
      ),
    );
  }
}

/// Pestaña con arrastrar para actualizar: [encabezado], el error de la última consulta y, mientras carga por
/// primera vez, el esqueleto; con datos, [contenido].
class _Pestana<T> extends StatelessWidget {
  final AnalyticsState state;
  final T? report;
  final Future<void> Function() onRefresh;
  final Widget? encabezado;
  final List<Widget> Function(T report) contenido;

  const _Pestana({required this.state, required this.report, required this.onRefresh, required this.contenido, this.encabezado});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final error = state.error;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16).withBottomSafeArea(context),
        children: [
          if (encabezado != null) encabezado!,
          if (error != null) _ErrorBanner(error: error),
          if (r != null) ...contenido(r) else if (state.status == AnalyticsStatus.loading) const _Esqueleto(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// TAB 1: GASTOS POR CATEGORÍA
// -------------------------------------------------------------
class _TabCategorias extends ConsumerWidget {
  const _TabCategorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsNotifierProvider);
    final notifier = ref.read(analyticsNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Pestana<CategoryExpenseReportEntity>(
      state: state,
      report: state.categoryReport,
      onRefresh: notifier.cargarReporteCategorias,
      encabezado: Padding(padding: const EdgeInsets.only(bottom: 16), child: _Periodos(state: state)),
      contenido: (report) => [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: isDark ? 0 : 2,
          child: Padding(padding: const EdgeInsets.all(16), child: CategoryPieChart(report: report)),
        ),
        const SizedBox(height: 16),
        if (report.subcategorias.isNotEmpty) _ConceptosFrecuentes(subcategorias: report.subcategorias),
      ],
    );
  }
}

/// Mes, mes anterior, año y un rango elegido.
class _Periodos extends ConsumerWidget {
  final AnalyticsState state;
  const _Periodos({required this.state});

  Future<void> _rango(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: state.desde, end: state.hasta),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: context.l10n.selectRangeReport,
    );
    if (picked == null) return;
    AppFeedback.selection();
    await ref.read(analyticsNotifierProvider.notifier).cambiarRangoFechas(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final f = DateFormat('dd/MM/yyyy');
    Widget chip(String key, String label) {
      final selected = state.selectedPeriodo == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: AppColors.primary.withValues(alpha: 0.18),
          labelStyle: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppColors.primary : null),
          onSelected: (_) {
            AppFeedback.selection();
            ref.read(analyticsNotifierProvider.notifier).cambiarPeriodo(key);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('mes_actual', l10n.month),
          chip('mes_anterior', l10n.previousMonth),
          chip('anio_actual', l10n.currentYear),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 14),
            label: Text(state.selectedPeriodo == 'personalizado' ? '${f.format(state.desde)} - ${f.format(state.hasta)}' : l10n.custom),
            onPressed: () => _rango(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Conceptos más frecuentes con su monto y porcentaje.
class _ConceptosFrecuentes extends StatelessWidget {
  final List<SubcategoryExpenseItemEntity> subcategorias;
  const _ConceptosFrecuentes({required this.subcategorias});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = reportCurrency(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.frequentConceptsDetail, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isDark ? 0 : 1,
          child: Column(
            children: [
              for (final (i, sub) in subcategorias.indexed) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(sub.etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: _MontoYDetalle(
                    monto: Money.format(sub.montoCents, currency: currency),
                    detalle: '${sub.porcentaje.toStringAsFixed(1)}%',
                    detalleColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MontoYDetalle extends StatelessWidget {
  final String monto;
  final String detalle;
  final Color? montoColor;
  final Color? detalleColor;
  const _MontoYDetalle({required this.monto, required this.detalle, this.montoColor, this.detalleColor});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(monto, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: montoColor)),
          Text(detalle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: detalleColor ?? montoColor)),
        ],
      );
}

// -------------------------------------------------------------
// TAB 2: COMPARATIVA ANUAL (INGRESOS VS EGRESOS)
// -------------------------------------------------------------
class _TabComparativa extends ConsumerWidget {
  const _TabComparativa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsNotifierProvider);
    final notifier = ref.read(analyticsNotifierProvider.notifier);
    final report = state.monthlyReport;
    final l10n = context.l10n;
    final currency = reportCurrency(context);
    return _Pestana<MonthlyComparisonReportEntity>(
      state: state,
      report: report,
      onRefresh: notifier.cargarComparativaMensual,
      encabezado: report == null ? null : _SelectorAnio(anio: state.selectedAnio, anios: report.aniosDisponibles),
      contenido: (report) {
        final t = report.totalesAnuales;
        return [
          _Kpis([
            _KpiCard(title: l10n.annualIncome, value: Money.format(t.totalIngresosCents, currency: currency), icon: Icons.arrow_downward_rounded, color: AppColors.emerald),
            _KpiCard(title: l10n.annualExpenses, value: Money.format(t.totalEgresosCents, currency: currency), icon: Icons.arrow_upward_rounded, color: AppColors.rose),
          ]),
          const SizedBox(height: 10),
          _Kpis([
            _KpiCard(
              title: l10n.netBalance,
              value: Money.format(t.balanceNetoCents, currency: currency),
              icon: Icons.savings_outlined,
              color: t.balanceNetoCents >= 0 ? AppColors.emerald : AppColors.rose,
            ),
            _KpiCard(title: l10n.savingsRate, value: Money.percent(t.tasaAhorroPorcentaje), icon: Icons.percent_rounded, color: AppColors.primary),
          ]),
          const SizedBox(height: 16),
          _Grafico(titulo: l10n.incomeVsExpensesMonth, child: MonthlyBarChart(report: report)),
          const SizedBox(height: 16),
          _DesgloseMensual(meses: report.meses),
        ];
      },
    );
  }
}

class _SelectorAnio extends ConsumerWidget {
  final int anio;
  final List<int> anios;
  const _SelectorAnio({required this.anio, required this.anios});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.l10n.annualOverview, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('anio-comparativa'),
                value: anio,
                isDense: true,
                items: [
                  for (final a in anios) DropdownMenuItem<int>(value: a, child: Text('$a', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) {
                  AppFeedback.selection();
                  ref.read(analyticsNotifierProvider.notifier).cargarComparativaMensual(anio: val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ingresos, egresos y balance de cada mes.
class _DesgloseMensual extends StatelessWidget {
  final List<MonthFinancialDataEntity> meses;
  const _DesgloseMensual({required this.meses});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = reportCurrency(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.detailedMonthlyBreakdown, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isDark ? 0 : 1,
          child: Column(
            children: [
              for (final (i, m) in meses.indexed) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(context.monthName(m.mes), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      Text(l10n.incIngresoscents(Money.format(m.ingresosCents, currency: currency)), style: const TextStyle(fontSize: 11, color: AppColors.emerald)),
                      Text(l10n.expEgresoscents(Money.format(m.egresosCents, currency: currency)), style: const TextStyle(fontSize: 11, color: AppColors.rose)),
                    ],
                  ),
                  trailing: _MontoYDetalle(
                    monto: Money.format(m.balanceCents, currency: currency),
                    detalle: m.esSuperavit ? l10n.surplus : l10n.deficit,
                    montoColor: m.esSuperavit ? AppColors.emerald : AppColors.rose,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// TAB 3: EVOLUCIÓN DÍA A DÍA
// -------------------------------------------------------------
class _TabDiaria extends ConsumerWidget {
  const _TabDiaria();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsNotifierProvider);
    final notifier = ref.read(analyticsNotifierProvider.notifier);
    final l10n = context.l10n;
    final currency = reportCurrency(context);
    return _Pestana(
      state: state,
      report: state.dailyReport,
      onRefresh: notifier.cargarEvolucionDiaria,
      encabezado: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(l10n.dailySpendingCurve, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('mes-diario'),
                value: state.selectedMesDiario,
                isDense: true,
                items: [
                  for (var mes = 1; mes <= 12; mes++)
                    DropdownMenuItem<int>(value: mes, child: Text(_capitalizar(context.monthName(mes)), style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) {
                  AppFeedback.selection();
                  notifier.cargarEvolucionDiaria(mes: val);
                },
              ),
            ),
          ],
        ),
      ),
      contenido: (report) => [
        _Kpis([
          _KpiCard(title: l10n.monthTotal, value: Money.format(report.totalEgresosMesCents, currency: currency), icon: Icons.payments_outlined, color: AppColors.primary),
          _KpiCard(title: l10n.highestPeak, value: Money.format(report.maximoGastoDiarioCents, currency: currency), icon: Icons.trending_up_rounded, color: AppColors.rose),
        ]),
        const SizedBox(height: 16),
        _Grafico(titulo: l10n.dailyExpenseTrend, child: DailyLineChart(report: report)),
      ],
    );
  }

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Error de la última consulta, con su código.
class _ErrorBanner extends StatelessWidget {
  final Object error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final code = ErrorMessages.codeOf(error);
    return Container(
      key: const ValueKey('reporte-error'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Text(ErrorMessages.describe(error, context.l10n) + (code != null ? ' ($code)' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Dos indicadores lado a lado.
class _Kpis extends StatelessWidget {
  final List<_KpiCard> cards;
  const _Kpis(this.cards);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: card)],
        ],
      );
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Tarjeta con título para un gráfico.
class _Grafico extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Grafico({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShimmerEffect(
                child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              ),
            ),
        ],
      );
}
