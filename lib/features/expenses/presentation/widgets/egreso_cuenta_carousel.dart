import 'package:flutter/material.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/form_screen_theme.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../../l10n/l10n.dart';

/// Carrusel de cuentas de origen de "Nuevo Egreso" (íconos reales de cada cuenta y su saldo local).
/// Seleccionada: borde rosa de 2 px y punto rosa junto al nombre. Las otras pantallas usan AccountPicker.
class EgresoCuentaCarousel extends StatelessWidget {
  final List<LocalAccount> cuentas;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  /// Margen lateral de la pantalla: el carrusel llega a los bordes pero arranca alineado.
  final double sidePadding;

  const EgresoCuentaCarousel({super.key, required this.cuentas, required this.selectedId, required this.onSelect, this.sidePadding = 20});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);

    if (cuentas.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(FormScreenTheme.radius),
            border: Border.all(color: t.border),
          ),
          child: Text(context.l10n.noAccountsPhoneSyncWhile, style: TextStyle(color: t.text)),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        itemCount: cuentas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cuenta = cuentas[index];
          final isSelected = cuenta.localId == selectedId;
          return Opacity(
            opacity: isSelected ? 1 : 0.85,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('cuenta-${cuenta.name}'),
                onTap: () {
                  AppFeedback.selection();
                  onSelect(cuenta.localId);
                },
                borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  // Mismo tamaño seleccionada o no: el borde de 2 px se compensa con el relleno.
                  padding: EdgeInsets.fromLTRB(isSelected ? 11 : 12, isSelected ? 11 : 12, isSelected ? 15 : 16, isSelected ? 11 : 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                    border: Border.all(color: isSelected ? t.accent : t.border, width: isSelected ? 2 : 1),
                    boxShadow: t.shadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AccountAvatar(imageUrl: cuenta.imageUrl, iconRef: cuenta.iconRef, currency: cuenta.currency, size: 44),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cuenta.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? t.title : t.fieldLabel,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Money.format(cuenta.balanceCents, currency: cuenta.currency),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cuenta.balanceCents < 0 ? t.accentStrong : t.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
