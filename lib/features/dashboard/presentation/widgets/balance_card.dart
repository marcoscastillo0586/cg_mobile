import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/l10n.dart';

class BalanceCard extends StatelessWidget {
  final int totalArsCents;

  /// Texto de la cotización usada (p. ej. "Blue: $ 1.250,00" o "sin conexión").
  final String? cotizacionTexto;
  final bool ocultarMontos;
  final VoidCallback onToggleOcultar;
  final VoidCallback onSelectFecha;
  final String? fechaFiltro;

  const BalanceCard({
    super.key,
    required this.totalArsCents,
    this.cotizacionTexto,
    required this.ocultarMontos,
    required this.onToggleOcultar,
    required this.onSelectFecha,
    this.fechaFiltro,
  });

  @override
  Widget build(BuildContext context) {
    final fechaFormatted = AppDateUtils.formatDateString(fechaFiltro);
    final montoFormateado = Money.format(totalArsCents, hidden: ocultarMontos);

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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.consolidatedBalances,
                      style: const TextStyle(
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
                    tooltip: context.l10n.hideBalances,
                    onPressed: onToggleOcultar,
                  ),
                  IconButton(
                    icon: Icon(
                      fechaFiltro != null ? Icons.filter_alt : Icons.calendar_month_outlined,
                      color: fechaFiltro != null ? AppColors.amber : Colors.white70,
                      size: 20,
                    ),
                    tooltip: context.l10n.filterDate,
                    onPressed: onSelectFecha,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Monto Principal (Saldo Consolidado con símbolo al inicio: "$ 1.200,00")
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              montoFormateado,
              key: const ValueKey('saldo-consolidado'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (cotizacionTexto != null) ...[
            const SizedBox(height: 6),
            Text(
              cotizacionTexto!,
              key: const ValueKey('cotizacion'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],

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
                    context.l10n.untilFechaformatted(fechaFormatted),
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
