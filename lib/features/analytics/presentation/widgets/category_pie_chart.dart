import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_touch.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/category_expense_report_entity.dart';
import '../../../../l10n/l10n.dart';
import '../report_currency.dart';

class CategoryPieChart extends StatefulWidget {
  final CategoryExpenseReportEntity report;

  const CategoryPieChart({
    super.key,
    required this.report,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  static const List<Color> _chartColors = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFF43F5E), // Rose
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF3B82F6), // Blue
    Color(0xFF84CC16), // Lime
    Color(0xFF6366F1), // Violet
  ];

  Color _getColor(int index) {
    return _chartColors[index % _chartColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final categorias = widget.report.categorias;

    if (categorias.isEmpty || widget.report.totalCents <= 0) return const _SinGastos();
    final seleccionada = _touchedIndex >= 0 && _touchedIndex < categorias.length ? categorias[_touchedIndex] : null;

    return Column(
      children: [
        // Gráfico Donut Interactivo
        SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final nuevo = resaltadoTrasToque(
                          interesado: event.isInterestedForInteractions, tocado: response?.touchedSection?.touchedSectionIndex);
                      if (nuevo == _touchedIndex) return;
                      if (nuevo >= 0) AppFeedback.selection();
                      setState(() => _touchedIndex = nuevo);
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 65,
                  sections: List.generate(categorias.length, (i) {
                    final item = categorias[i];
                    final isTouched = i == _touchedIndex;
                    final radius = isTouched ? 36.0 : 28.0;
                    final color = _getColor(i);

                    return PieChartSectionData(
                      color: color,
                      // Solo geometría del gráfico (el texto se formatea desde centavos).
                      value: item.montoCents.toDouble(),
                      title: '', // Donut minimalista, detalles en el centro o lista
                      radius: radius,
                      badgeWidget: isTouched
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.porcentaje.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      badgePositionPercentageOffset: 1.15,
                    );
                  }),
                ),
                duration: const Duration(milliseconds: 250),
              ),

              // Contenido en el centro del Donut
              _Centro(
                seleccionada: seleccionada,
                color: seleccionada == null ? null : _getColor(_touchedIndex),
                totalCents: widget.report.totalCents,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista Desglosada de Categorías
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categorias.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, index) {
            final cat = categorias[index];
            final color = _getColor(index);
            final isSelected = index == _touchedIndex;

            return InkWell(
              onTap: () {
                AppFeedback.selection();
                setState(() {
                  _touchedIndex = (_touchedIndex == index) ? -1 : index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.nombre,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Money.format(cat.montoCents, currency: reportCurrency(context)),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? color : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cat.porcentaje.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Sin gastos en el período: no hay torta.
class _SinGastos extends StatelessWidget {
  const _SinGastos();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 260,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 54, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            context.l10n.noExpensesPeriod,
            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ],
      ),
    );
  }
}

/// Centro de la dona: la categoría elegida (nombre, monto y porcentaje) o el total del período.
class _Centro extends StatelessWidget {
  final CategoryExpenseItemEntity? seleccionada;
  final Color? color;
  final int totalCents;
  const _Centro({required this.seleccionada, required this.color, required this.totalCents});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel = seleccionada;
    final currency = reportCurrency(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sel?.nombre ?? context.l10n.totalExpenses,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          Money.format(sel?.montoCents ?? totalCents, currency: currency),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color ?? (isDark ? Colors.white : AppColors.lightTextPrimary)),
        ),
        if (sel != null)
          Text(context.l10n.tostringasfixedTotal(sel.porcentaje.toStringAsFixed(1)), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
