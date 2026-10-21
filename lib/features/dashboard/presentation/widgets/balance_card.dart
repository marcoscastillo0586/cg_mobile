import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';

class BalanceCard extends StatelessWidget {
  final double totalPesos;
  final bool ocultarMontos;
  final VoidCallback onToggleOcultar;
  final VoidCallback onSelectFecha;
  final String? fechaFiltro;

  const BalanceCard({
    super.key,
    required this.totalPesos,
    required this.ocultarMontos,
    required this.onToggleOcultar,
    required this.onSelectFecha,
    this.fechaFiltro,
  });

  @override
  Widget build(BuildContext context) {
    final fechaFormatted = AppDateUtils.formatDateString(fechaFiltro);
    final montoFormateado = AppCurrencyUtils.format(
      totalPesos,
      symbol: '\$',
      ocultar: ocultarMontos,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF3730A3),
            Color(0xFF1E1B4B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Saldos Consolidados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      ocultarMontos ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    tooltip: 'Ocultar saldos',
                    onPressed: onToggleOcultar,
                  ),
                  IconButton(
                    icon: Icon(
                      fechaFiltro != null ? Icons.filter_alt : Icons.calendar_month_outlined,
                      color: fechaFiltro != null ? AppColors.amber : Colors.white70,
                      size: 20,
                    ),
                    tooltip: 'Filtrar por fecha',
                    onPressed: onSelectFecha,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Monto Principal (Saldo Consolidado con símbolo al inicio: "$ 1.200,00")
          Text(
            montoFormateado,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          if (fechaFiltro != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: AppColors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Hasta: $fechaFormatted',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
