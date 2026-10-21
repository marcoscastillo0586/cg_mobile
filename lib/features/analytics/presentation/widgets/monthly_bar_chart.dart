import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/monthly_comparison_entity.dart';

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

  static const List<String> _shortMonths = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.compactCurrency(locale: 'es_AR', symbol: '\$', decimalDigits: 1);
    final fullCurrencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2);
    final meses = widget.report.meses;

    // Calcular valor máximo para escalar el eje Y
    double maxMonto = 0;
    for (final m in meses) {
      if (m.ingresos > maxMonto) maxMonto = m.ingresos;
      if (m.egresos > maxMonto) maxMonto = m.egresos;
    }
    if (maxMonto == 0) maxMonto = 100000;
    final yInterval = (maxMonto / 4).ceilToDouble();

    return Column(
      children: [
        // Leyenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(AppColors.emerald, 'Ingresos'),
            const SizedBox(width: 24),
            _buildLegendItem(AppColors.rose, 'Egresos'),
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
                    final tipo = isIngreso ? 'Ingresos' : 'Egresos';
                    final valor = isIngreso ? mesData.ingresos : mesData.egresos;

                    return BarTooltipItem(
                      '${mesData.nombreMes}\n$tipo: ${fullCurrencyFormat.format(valor)}\nBalance: ${fullCurrencyFormat.format(mesData.balance)}',
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
                      if (index < 0 || index >= _shortMonths.length) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = index == _touchedGroupIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _shortMonths[index],
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
                      toY: m.ingresos,
                      color: AppColors.emerald,
                      width: isSelected ? 9 : 7,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    // Barra de Egreso
                    BarChartRodData(
                      toY: m.egresos,
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
