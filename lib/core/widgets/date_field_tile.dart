import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

/// Campo de fecha de los formularios (dd/MM/aaaa); al tocarlo, [onTap] abre el selector.
class DateFieldTile extends StatelessWidget {
  final DateTime fecha;
  final VoidCallback onTap;
  const DateFieldTile({super.key, required this.fecha, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 10),
                Text(DateFormat('dd/MM/yyyy').format(fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
