import 'package:flutter/material.dart';

// La app se dibuja de borde a borde (targetSdk 36: Android 15+ lo impone y Android 16 no permite desactivarlo),
// así que la barra de navegación del sistema (3 botones o gestos) queda ENCIMA del fondo de cada pantalla.
// Todo lo que va al fondo suma el margen inferior del sistema que informa MediaQuery (nunca un número fijo).
// Se usa `padding` (no `viewPadding`): con el teclado abierto vale 0, porque la barra queda debajo del teclado.

/// Margen inferior del sistema (barra de navegación); 0 con el teclado abierto.
double systemBottomInset(BuildContext context) => MediaQuery.paddingOf(context).bottom;

extension BottomSafeInsets on EdgeInsets {
  /// El mismo padding más el margen inferior del sistema (y [extra], p. ej. el alto de un botón fijo encima),
  /// para que el último elemento de una lista o formulario desplazable no quede detrás de la barra.
  EdgeInsets withBottomSafeArea(BuildContext context, {double extra = 0}) =>
      copyWith(bottom: bottom + extra + systemBottomInset(context));
}

/// Botón o barra de acciones fija al fondo de la pantalla, siempre por encima de la barra de navegación
/// del sistema: al [padding] de diseño le suma el margen inferior del sistema.
/// Con [fadeColor], detrás pinta un degradé (de transparente a [fadeColor]) que llega hasta el borde inferior
/// físico de la pantalla, para que el contenido desplazable se desvanezca por detrás.
class BottomActionArea extends StatelessWidget {
  final Widget child;

  /// Espaciado de diseño alrededor de [child] (sin contar el margen del sistema).
  final EdgeInsets padding;
  final Color? fadeColor;

  const BottomActionArea({super.key, required this.child, this.padding = EdgeInsets.zero, this.fadeColor});

  /// Alto total que ocupa el área (contenido de alto [childHeight] + padding + margen del sistema): espacio
  /// inferior que necesita el contenido desplazable que pasa por detrás.
  static double reservedHeight(BuildContext context, {required double childHeight, EdgeInsets padding = EdgeInsets.zero}) =>
      childHeight + padding.vertical + systemBottomInset(context);

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding.withBottomSafeArea(context), child: child);
    final fade = fadeColor;
    if (fade == null) return content;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [fade, fade.withValues(alpha: 0.95), fade.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        content,
      ],
    );
  }
}
