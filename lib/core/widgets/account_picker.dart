import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../database/local_catalog.dart';
import '../money/money.dart';
import '../utils/app_feedback.dart';
import 'account_avatar.dart';
import '../../l10n/l10n.dart';

/// Selector horizontal de cuentas de la base local, con su saldo local (descuenta lo pendiente).
class AccountPicker extends StatelessWidget {
  final List<LocalAccount> cuentas;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const AccountPicker({super.key, required this.cuentas, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cuentas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Text(context.l10n.noAccountsPhoneSyncWhile),
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
          final isSelected = cuenta.localId == selectedId;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('cuenta-${cuenta.name}'),
              onTap: () {
                AppFeedback.selection();
                onSelect(cuenta.localId);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccountAvatar(imageUrl: cuenta.imageUrl, iconRef: cuenta.iconRef, currency: cuenta.currency, size: 36),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cuenta.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? (isDark ? Colors.white : AppColors.primaryDark) : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.format(cuenta.balanceCents, currency: cuenta.currency),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cuenta.balanceCents < 0
                                ? AppColors.rose
                                : (isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
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

/// Texto del aviso de saldo negativo (egresos): la cuenta queda en negativo y conviene registrar un ingreso.
String negativeBalanceText(LocalAccount cuenta, int amountCents, AppLocalizations l) {
  final queda = Money.format(cuenta.balanceCents - amountCents, currency: cuenta.currency);
  return l.willRecordIncomeThatAccount(cuenta.name.toUpperCase(), queda);
}

/// Aviso de fondos ANTES de guardar.
/// - [blocking] (transferencias): no se puede guardar; hay que registrar un ingreso en el origen.
/// - sin bloquear (egresos): la cuenta quedaría en negativo; se puede guardar igual tras confirmar.
class FundsWarning extends StatelessWidget {
  final LocalAccount cuenta;
  final int amountCents;
  final bool blocking;
  const FundsWarning({super.key, required this.cuenta, required this.amountCents, this.blocking = false});

  @override
  Widget build(BuildContext context) {
    final disponible = Money.format(cuenta.balanceCents, currency: cuenta.currency);
    final total = Money.format(amountCents, currency: cuenta.currency);
    final color = blocking ? AppColors.rose : AppColors.amberDark;
    final text = blocking
        ? (context.l10n.notEnoughBalanceTransferAvailable(total, cuenta.name.toUpperCase(), disponible))
        : negativeBalanceText(cuenta, amountCents, context.l10n);
    return Container(
      key: const ValueKey('aviso-fondos'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
        ],
      ),
    );
  }
}
