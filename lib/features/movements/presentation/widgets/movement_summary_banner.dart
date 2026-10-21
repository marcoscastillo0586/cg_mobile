import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/movement_entity.dart';

class MovementSummaryBanner extends StatelessWidget {
  final MovementsSummaryEntity resumen;
  final String? desde;
  final String? hasta;

  const MovementSummaryBanner({
    super.key,
    required this.resumen,
    this.desde,
    this.hasta,
  });

  String _formatear(double monto) {
    return AppCurrencyUtils.format(
      monto,
      symbol: '\$',
      showDecimals: false,
    );
  }

  String _obtenerTextoPeriodo() {
    if (desde != null && desde!.isNotEmpty && hasta != null && hasta!.isNotEmpty) {
      return '${AppDateUtils.formatDateString(desde)} - ${AppDateUtils.formatDateString(hasta)}';
    }
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0);
    return '${AppDateUtils.formatDate(inicioMes)} - ${AppDateUtils.formatDate(finMes)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textoPeriodo = _obtenerTextoPeriodo();

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // Período de fechas filtrado
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Período: $textoPeriodo',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Métricas de Ingresos / Egresos / Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Total Ingresos
              Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_downward, color: AppColors.emerald, size: 14),
                      SizedBox(width: 4),
                      Text('Ingresos', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatear(resumen.totalIngresos),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.emerald),
                  ),
                ],
              ),

              Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

              // Total Egresos
              Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_upward, color: AppColors.rose, size: 14),
                      SizedBox(width: 4),
                      Text('Egresos', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatear(resumen.totalEgresos),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.rose),
                  ),
                ],
              ),

              Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

              // Balance Neto
              Column(
                children: [
                  const Text('Balance', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _formatear(resumen.balancePeriodo),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: resumen.balancePeriodo >= 0 ? AppColors.emerald : AppColors.rose,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
