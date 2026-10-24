import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/monthly_comparison_entity.dart';
import '../../../../l10n/l10n.dart';

class MonthlyBarChart extends StatefulWidget {
  final MonthlyComparisonReportEntity report;

  const MonthlyBarChart({
    super.key,
    required this.report,
  });

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int _touchedGroupIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.compactCurrency(locale: 'es_AR', symbol: '\$', decimalDigits: 1);
    final meses = widget.report.meses;

    // El gráfico dibuja en pesos (double solo para la geometría); los textos salen de centavos.
    double maxMonto = 0;
    for (final m in meses) {
      if (m.ingresosCents / 100 > maxMonto) maxMonto = m.ingresosCents / 100;
      if (m.egresosCents / 100 > maxMonto) maxMonto = m.egresosCents / 100;
    }
    if (maxMonto == 0) maxMonto = 100000;
    final yInterval = (maxMonto / 4).ceilToDouble();

    return Column(
      children: [
        // Leyenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(AppColors.emerald, context.l10n.income2),
            const SizedBox(width: 24),
            _buildLegendItem(AppColors.rose, context.l10n.expenses),
          ],
        ),
        const SizedBox(height: 16),

        // Gráfico de Barras Agrupadas
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxMonto * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final mesData = meses[group.x];
                    final isIngreso = rodIndex == 0;
                    final tipo = isIngreso ? context.l10n.income2 : context.l10n.expenses;
                    final valor = isIngreso ? mesData.ingresosCents : mesData.egresosCents;

                    return BarTooltipItem(
                      context.l10n.chartMonthTooltip(context.monthName(mesData.mes), tipo, Money.format(valor), Money.format(mesData.balanceCents)),
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.spot == null) {
                      _touchedGroupIndex = -1;
                      return;
                    }
                    _touchedGroupIndex = response.spot!.touchedBarGroupIndex;
                  });
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: yInterval > 0 ? yInterval : 50000,
                    getTitlesWidget: (val, meta) {
                      if (val == 0) return const SizedBox.shrink();
                      return Text(
                        currencyFormat.format(val),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final index = val.toInt();
                      if (index < 0 || index >= 12) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = index == _touchedGroupIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          context.monthName(index + 1, short: true),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval > 0 ? yInterval : 50000,
                getDrawingHorizontalLine: (val) {
                  return FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(meses.length, (i) {
                final m = meses[i];
                final isSelected = i == _touchedGroupIndex;

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    // Barra de Ingreso
                    BarChartRodData(
                      toY: m.ingresosCents / 100,
                      color: AppColors.emerald,
                      width: isSelected ? 9 : 7,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    // Barra de Egreso
                    BarChartRodData(
                      toY: m.egresosCents / 100,
                      color: AppColors.rose,
                      width: isSelected ? 9 : 7,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
