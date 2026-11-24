import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

/// Eje de montos de los gráficos de informes: abreviado (\$ 1,5 mil), sin el cero, cada [interval] (si el máximo
/// es cero, cada [porDefecto]).
SideTitles ejeMontos(BuildContext context, {required double interval, required double porDefecto}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final formato = NumberFormat.compactCurrency(locale: 'es_AR', symbol: '\$', decimalDigits: 1);
  return SideTitles(
    showTitles: true,
    reservedSize: 42,
    interval: interval > 0 ? interval : porDefecto,
    getTitlesWidget: (val, meta) => val == 0
        ? const SizedBox.shrink()
        : Text(formato.format(val), style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
  );
}
