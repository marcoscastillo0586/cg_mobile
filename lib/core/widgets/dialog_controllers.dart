import 'package:flutter/material.dart';

/// Dueño de los TextEditingController de un diálogo: los crea al montarse y los libera cuando
/// el diálogo se desmonta DE VERDAD (después de su animación de cierre). Liberarlos apenas
/// vuelve `showDialog` rompe el TextField que todavía se está cerrando
/// (assertion `_dependents.isEmpty`). El diálogo debe devolver los valores con Navigator.pop.
class DialogControllers extends StatefulWidget {
  final List<String> initial;
  final Widget Function(BuildContext context, List<TextEditingController> controllers) builder;

  const DialogControllers({super.key, required this.initial, required this.builder});

  @override
  State<DialogControllers> createState() => _DialogControllersState();
}

class _DialogControllersState extends State<DialogControllers> {
  late final List<TextEditingController> _controllers = [for (final t in widget.initial) TextEditingController(text: t)];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}
