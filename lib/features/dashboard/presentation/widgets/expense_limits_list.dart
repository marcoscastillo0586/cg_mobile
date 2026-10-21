import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/expense_limit_entity.dart';

class ExpenseLimitsList extends StatelessWidget {
  final List<ExpenseLimitEntity> limites;
  final bool ocultarMontos;
  final VoidCallback? onCrearNuevo;

  const ExpenseLimitsList({
    super.key,
    required this.limites,
    required this.ocultarMontos,
    this.onCrearNuevo,
  });

  String _formatear(double monto) {
    return AppCurrencyUtils.format(
      monto,
      symbol: '\$',
      showDecimals: false,
      ocultar: ocultarMontos,
    );
  }

  Color _obtenerColorProgreso(double porcentaje, bool vencido) {
    if (vencido || porcentaje >= 100) return AppColors.rose;
    if (porcentaje >= 80) return AppColors.amber;
    return AppColors.emerald;
  }

  @override
  Widget build(BuildContext context) {
    if (limites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 54,
                color: AppColors.lightTextSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No tienes presupuestos o límites activos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Crea topes de gasto por categoría para mantener tus finanzas bajo control.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
              ),
              if (onCrearNuevo != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onCrearNuevo,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear Nuevo Presupuesto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onCrearNuevo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Topes Activos (${limites.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                ElevatedButton.icon(
                  onPressed: onCrearNuevo,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Nuevo Presupuesto', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = limites[index];
            final color = _obtenerColorProgreso(item.porcentaje, item.vencido);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.vencido ? 'VENCIDO' : '${item.porcentaje.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.categorias} • ${item.lugares}',
                      style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (item.porcentaje / 100).clamp(0.0, 1.0),
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gastado: ${_formatear(item.montoConsumido)} / ${_formatear(item.montoLimite)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Disponible: ${_formatear(item.resto)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.resto < 0 ? AppColors.rose : AppColors.emerald,
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
