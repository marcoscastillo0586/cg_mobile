import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/l10n.dart';

class QuickActionsBar extends StatelessWidget {
  final VoidCallback onNuevoGasto;
  final VoidCallback onNuevoIngreso;
  final VoidCallback onNuevaTransferencia;
  final VoidCallback onVerHistorial;

  const QuickActionsBar({
    super.key,
    required this.onNuevoGasto,
    required this.onNuevoIngreso,
    required this.onNuevaTransferencia,
    required this.onVerHistorial,
  });

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.arrow_upward_rounded,
          label: context.l10n.expense,
          color: AppColors.rose,
          onTap: onNuevoGasto,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.arrow_downward_rounded,
          label: context.l10n.income,
          color: AppColors.emerald,
          onTap: onNuevoIngreso,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.swap_horiz_rounded,
          label: context.l10n.transfer2,
          color: AppColors.primary,
          onTap: onNuevaTransferencia,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.receipt_long_rounded,
          label: context.l10n.history,
          color: AppColors.amber,
          onTap: onVerHistorial,
        ),
      ],
    );
  }
}
