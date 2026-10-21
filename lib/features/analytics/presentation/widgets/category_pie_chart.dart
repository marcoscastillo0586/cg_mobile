import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/category_expense_report_entity.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categorias = widget.report.categorias;

    if (categorias.isEmpty || widget.report.totalCents <= 0) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No hay egresos en este período',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

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
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (newIndex != _touchedIndex) {
                          AppFeedback.selection();
                          _touchedIndex = newIndex;
                        }
                      });
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _touchedIndex >= 0 && _touchedIndex < categorias.length
                        ? categorias[_touchedIndex].nombre
                        : 'Total Gastos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _touchedIndex >= 0 && _touchedIndex < categorias.length
                        ? Money.format(categorias[_touchedIndex].montoCents)
                        : Money.format(widget.report.totalCents),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _touchedIndex >= 0 && _touchedIndex < categorias.length
                          ? _getColor(_touchedIndex)
                          : (isDark ? Colors.white : AppColors.lightTextPrimary),
                    ),
                  ),
                  if (_touchedIndex >= 0 && _touchedIndex < categorias.length)
                    Text(
                      '${categorias[_touchedIndex].porcentaje.toStringAsFixed(1)}% del total',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
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
                          Money.format(cat.montoCents),
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
