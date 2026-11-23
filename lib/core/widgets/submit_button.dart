import 'package:flutter/material.dart';

/// Botón de guardar de un formulario: deshabilitado y con indicador mientras guarda.
class SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Color color;
  final VoidCallback onPressed;
  const SubmitButton({super.key, required this.label, required this.loading, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(label),
      );
}
