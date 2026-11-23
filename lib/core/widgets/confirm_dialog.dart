import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// "¿Seguro?" con Cancelar y [action]. true solo si eligió [action] (cerrar o Cancelar = false).
Future<bool> confirmar(BuildContext context, {required String title, required String message, required String action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
        TextButton(key: const ValueKey('confirmar-accion'), onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}
