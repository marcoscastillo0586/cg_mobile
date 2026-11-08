import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/form_screen_theme.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../../l10n/l10n.dart';
import 'egreso_estilo.dart';

/// Carrusel de cuentas de origen de "Nuevo Egreso" (íconos reales de cada cuenta y su saldo local).
/// Seleccionada: borde índigo de 2 px, sombra índigo y check en la esquina. Las otras pantallas usan AccountPicker.
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
    final e = EgresoEstilo.of(context);

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

    // Alto según el tamaño de texto del sistema: nombre + saldo (o el ícono de 44), relleno y borde.
    final escala = MediaQuery.textScalerOf(context);
    final contenido = math.max(44.0, escala.scale(11) * 1.4 + 2 + escala.scale(16) * 1.4);
    final alto = contenido + EgresoEstilo.cuentaRelleno * 2 + 4;

    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        itemCount: cuentas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cuenta = cuentas[index];
          final isSelected = cuenta.localId == selectedId;
          // Mismo tamaño seleccionada o no: el borde de 2 px se compensa con el relleno.
          const r = EgresoEstilo.cuentaRelleno;
          final borde = isSelected ? 2.0 : 1.0;
          return Opacity(
            opacity: isSelected ? 1 : 0.85,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: EgresoEstilo.cuentaAnchoMin, maxWidth: EgresoEstilo.cuentaAnchoMax),
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
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                      border: Border.all(color: isSelected ? e.cuentaSeleccion : e.cuentaBorde, width: borde),
                      boxShadow: e.cuentaSombra(isSelected),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          // A la derecha queda lugar para el check (también sin seleccionar: el ancho no salta).
                          padding: EdgeInsets.fromLTRB(r - borde + 1, r - borde + 1, r + EgresoEstilo.cuentaCheck - borde + 1, r - borde + 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AccountAvatar(iconRef: cuenta.iconRef, size: 44),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cuenta.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: e.cuentaNombre(isSelected),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        Money.format(cuenta.balanceCents, currency: cuenta.currency),
                                        maxLines: 1,
                                        style: e.cuentaSaldo(isSelected, negativo: cuenta.balanceCents < 0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: EgresoEstilo.cuentaCheck,
                              height: EgresoEstilo.cuentaCheck,
                              decoration: BoxDecoration(
                                color: e.cuentaSeleccion,
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 3, offset: Offset(0, 1))],
                              ),
                              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
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
