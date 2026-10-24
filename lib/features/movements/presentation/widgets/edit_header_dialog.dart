import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../data/local_movement_editor.dart';
import '../../data/local_movement_writer.dart' show conceptMax;
import '../../domain/movement_item.dart';
import '../local_write_feedback.dart';

/// Edición mínima de un comprobante (concepto general y fecha; la hora se conserva).
/// Se guarda en la base local y en la outbox con `baseVersion`; el envío lo hace el
/// sincronizador. Devuelve true si se guardó.
Future<bool> editMovementHeader(BuildContext context, WidgetRef ref, MovementItem item, {required bool isEn}) async {
  final conceptCtrl = TextEditingController(text: item.generalConcept ?? '');
  var date = DateTime.tryParse(item.occurredAt.substring(0, 10)) ?? DateTime.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(isEn ? 'Edit movement' : 'Editar comprobante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('editar-concepto'),
              controller: conceptCtrl,
              maxLength: conceptMax,
              decoration: InputDecoration(labelText: isEn ? 'General concept' : 'Concepto general'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('editar-fecha'),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setLocal(() => date = picked);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEn ? 'Cancel' : 'Cancelar')),
          TextButton(key: const ValueKey('editar-guardar'), onPressed: () => Navigator.pop(ctx, true), child: Text(isEn ? 'Save' : 'Guardar')),
        ],
      ),
    ),
  );
  final concept = conceptCtrl.text;
  conceptCtrl.dispose();
  if (ok != true) return false;
  try {
    final db = await ref.read(localDatabaseProvider);
    final rows = await db.query('movement_headers', columns: ['local_id'], where: 'server_id = ? AND deleted = 0', whereArgs: [item.id]);
    if (rows.isEmpty) {
      throw Exception(isEn ? 'This movement is not on the phone yet: sync first.' : 'El comprobante todavía no está en el celular: sincronizá primero.');
    }
    await (await ref.read(localMovementEditorProvider)).updateHeader(rows.first['local_id']! as int, generalConcept: concept, date: date);
  } catch (e) {
    debugPrint('[EDITAR] No se guardó: $e');
    if (context.mounted) AppFeedback.showError(context, describeWithCode(e, isEn: isEn));
    return false;
  }
  if (context.mounted) {
    AppFeedback.showSuccess(context, isEn ? 'Change saved on this phone; sending…' : 'Cambio guardado en el celular; enviando…');
  }
  await ref.read(syncControllerProvider.notifier).sync();
  return true;
}
