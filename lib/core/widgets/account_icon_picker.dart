import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../l10n/l10n.dart';
import 'account_avatar.dart';
import 'account_icon_catalog.dart';

/// Selector de ícono de "Nueva cuenta" y edición: muestra todo el catálogo, sin texto visible en cada ícono.
/// Usa Wrap porque va dentro de un AlertDialog, que necesita conocer el ancho propio de su contenido.
class AccountIconPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const AccountIconPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 224,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in accountIconCatalog)
                Semantics(
                  button: true,
                  selected: value == e.key,
                  label: '${context.l10n.icon} ${e.key}',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('icono-${e.key}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(e.key),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: value == e.key ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: value == e.key ? 2.5 : 1,
                        ),
                      ),
                      child: AccountAvatar(iconRef: e.key, size: 40),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
