import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../dashboard/domain/entities/account_entity.dart';

class ExpenseAccountSelector extends StatelessWidget {
  final List<AccountEntity> cuentas;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const ExpenseAccountSelector({
    super.key,
    required this.cuentas,
    required this.selectedId,
    required this.onSelect,
  });

  IconData _getAccountIcon(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains('efectivo') || lower.contains('caja')) {
      return Icons.payments_outlined;
    } else if (lower.contains('mercado') || lower.contains('mp')) {
      return Icons.phone_android_rounded;
    } else if (lower.contains('banco') || lower.contains('galicia') || lower.contains('bbva') || lower.contains('santander') || lower.contains('nacion')) {
      return Icons.account_balance_outlined;
    } else if (lower.contains('dolar') || lower.contains('usd')) {
      return Icons.attach_money_rounded;
    } else if (lower.contains('tarjeta')) {
      return Icons.credit_card_rounded;
    }
    return Icons.account_balance_wallet_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cuentas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: const Text('No hay cuentas disponibles'),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cuentas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cuenta = cuentas[index];
          final isSelected = cuenta.idLugar == selectedId;
          final icon = _getAccountIcon(cuenta.nombre);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                AppFeedback.selection();
                onSelect(cuenta.idLugar);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkSurface.withValues(alpha: 0.8)
                                : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected ? Colors.white : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cuenta.nombre.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? Colors.white : AppColors.primaryDark)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cuenta.simboloMoneda} ${cuenta.montoOriginal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
