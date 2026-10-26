import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/daily_evolution_entity.dart';
import '../../../../l10n/l10n.dart';
import '../report_currency.dart';

class DailyLineChart extends StatelessWidget {
  final DailyEvolutionReportEntity report;

  const DailyLineChart({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.compactCurrency(locale: 'es_AR', symbol: '\$', decimalDigits: 1);
    final dias = report.dias;

    // El gráfico dibuja en pesos (double solo para la geometría); los textos salen de centavos.
    double maxGasto = report.maximoGastoDiarioCents / 100;
    if (maxGasto <= 0) maxGasto = 10000;
    final yInterval = (maxGasto / 4).ceilToDouble();

    final spots = dias.map((d) {
      return FlSpot(d.dia.toDouble(), d.egresosCents / 100);
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              maxY: maxGasto * 1.15,
              minY: 0,
              minX: 1,
              maxX: report.diasEnMes.toDouble(),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final diaNum = spot.x.toInt();
                      final item = dias.firstWhere(
                        (d) => d.dia == diaNum,
                        orElse: () => DailyEvolutionItemEntity(
                          dia: diaNum,
                          fecha: '',
                          ingresosCents: 0,
                          egresosCents: (spot.y * 100).round(),
                        ),
                      );
                      return LineTooltipItem(
                        context.l10n.dayDianumSpentEgresoscents(diaNum, Money.format(item.egresosCents, currency: reportCurrency(context))),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval > 0 ? yInterval : 5000,
                getDrawingHorizontalLine: (val) {
                  return FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: yInterval > 0 ? yInterval : 5000,
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
                    interval: 5,
                    getTitlesWidget: (val, meta) {
                      final dia = val.toInt();
                      if (dia < 1 || dia > report.diasEnMes) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$dia',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      // Solo resaltar días con gasto significativo o el pico más alto
                      return spot.y == report.maximoGastoDiarioCents / 100 && spot.y > 0;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: AppColors.rose,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.28),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
