import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/account_entity.dart';

class AccountCard extends StatelessWidget {
  final AccountEntity account;
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

  Widget _buildAvatar() {
    if (account.imgBase64 != null && account.imgBase64!.isNotEmpty) {
      try {
        final base64String = account.imgBase64!.split(',').last;
        final bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackAvatar(),
          ),
        );
      } catch (_) {
        return _fallbackAvatar();
      }
    }

    if (account.imgUrl != null && account.imgUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          account.imgUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final iconData = account.isUSD
        ? Icons.attach_money
        : (account.nombre.toLowerCase().contains('banco')
            ? Icons.account_balance
            : Icons.wallet);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: (account.isUSD ? AppColors.emerald : AppColors.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: account.isUSD ? AppColors.emerald : AppColors.primary,
        size: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = account.isUSD ? 'US\$' : '\$';
    final montoTexto = AppCurrencyUtils.format(
      account.montoOriginal,
      symbol: symbol,
      ocultar: ocultarMontos,
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              // Checkbox reactivo para sumar al saldo consolidado
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: onToggleSelection,
                ),
              ),
              const SizedBox(width: 8),

              _buildAvatar(),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.nombre.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (account.isUSD ? AppColors.emerald : AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        account.simboloMoneda,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: account.isUSD ? AppColors.emerald : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                montoTexto,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
