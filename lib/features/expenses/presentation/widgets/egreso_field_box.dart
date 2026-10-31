import 'package:flutter/material.dart';
import '../../../../core/theme/form_screen_theme.dart';

/// Caja de un campo del diseño de "Nuevo Egreso": borde fino, con foco borde rosa y halo suave.
/// [inner] = campo dentro de un renglón (radio 12, fondo gris claro sin foco).
class EgresoFieldBox extends StatefulWidget {
  final FocusNode? focusNode;
  final bool error;
  final bool inner;
  final Widget child;

  const EgresoFieldBox({super.key, this.focusNode, this.error = false, this.inner = false, required this.child});

  /// Decoración del TextField de adentro: sin bordes ni relleno propios (los pone la caja).
  static InputDecoration input({String? hint, Widget? prefixIcon, Widget? prefix, Widget? suffixIcon, bool inner = false, Color? hintColor}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14, fontWeight: FontWeight.w500),
        prefixIcon: prefixIcon,
        prefixIconConstraints: BoxConstraints(minWidth: inner ? 36 : 44, minHeight: 20),
        prefix: prefix,
        suffixIcon: suffixIcon,
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: inner ? const EdgeInsets.fromLTRB(0, 11, 12, 11) : const EdgeInsets.fromLTRB(0, 15, 16, 15),
      );

  @override
  State<EgresoFieldBox> createState() => _EgresoFieldBoxState();
}

class _EgresoFieldBoxState extends State<EgresoFieldBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant EgresoFieldBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocus);
      widget.focusNode?.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: t.fieldDecoration(focused: widget.focusNode?.hasFocus ?? false, error: widget.error, inner: widget.inner),
      child: widget.child,
    );
  }
}
