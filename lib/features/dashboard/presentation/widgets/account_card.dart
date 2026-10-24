import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../domain/entities/balances.dart';
import '../../../../l10n/l10n.dart';

class AccountCard extends StatelessWidget {
  final BalanceAccount account;
  final bool ocultarMontos;
  final bool isSelected;
  final ValueChanged<bool?>? onToggleSelection;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.ocultarMontos,
    this.isSelected = true,
    this.onToggleSelection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUsd = account.currency == Currency.usd;
    final color = isUsd ? AppColors.emerald : AppColors.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(value: isSelected, activeColor: AppColors.primary, onChanged: onToggleSelection),
              ),
              const SizedBox(width: 8),
              AccountAvatar(imageUrl: account.imageUrl, iconRef: account.iconRef, currency: account.currency),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        account.currency.code,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.format(account.balanceCents, currency: account.currency, hidden: ocultarMontos),
                      key: ValueKey('saldo-cuenta-${account.id}'),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        // En negativo: en rojo (falta registrar un ingreso en esa cuenta).
                        color: account.balanceCents < 0
                            ? AppColors.rose
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    if (account.balanceCents < 0 && !ocultarMontos)
                      Text(
                        context.l10n.recordIncome,
                        key: ValueKey('cuenta-negativa-${account.id}'),
                        style: const TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600),
                      ),
                    if (isUsd && !ocultarMontos)
                      Text(
                        account.balanceArsCents == null
                            ? (context.l10n.noExchangeRate)
                            : Money.format(account.balanceArsCents!),
                        style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
