import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/utils/app_feedback.dart';
import '../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../dashboard/presentation/providers/novedades_notifier.dart';

/// Texto traducido del error con su código, si lo tiene.
String describeWithCode(Object error, {required bool isEn}) {
  final code = ErrorMessages.codeOf(error);
  return ErrorMessages.describe(error, isEn: isEn) + (code != null && code != 'VALIDATION_ERROR' ? ' ($code)' : '');
}

/// Después de guardar en el celular: refresca los saldos locales y avisa, sin decir que llegó
/// al servidor (eso lo hace la sincronización).
Future<void> afterLocalWrite(BuildContext context, WidgetRef ref, String what, {required bool isEn}) async {
  int? pending;
  try {
    pending = await Outbox.pendingCount(await ref.read(localDatabaseProvider));
  } catch (e) {
    debugPrint('[OUTBOX] No se pudo contar lo pendiente: $e');
  }
  unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
  unawaited(ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
  // Si hay red se envía ya; si no, queda en la cola (el resultado se ve en Ajustes).
  unawaited(ref.read(syncControllerProvider.notifier).sync());
  if (!context.mounted) return;
  final suffix = pending == null ? '' : (isEn ? ' Pending: $pending.' : ' Pendientes: $pending.');
  AppFeedback.showSuccess(
    context,
    isEn
        ? '$what saved on this phone. It will be sent to the server when syncing.$suffix'
        : '$what guardado en el celular. Se enviará al servidor al sincronizar.$suffix',
  );
}

/// Pantalla de error cuando el formulario no puede leer la base local.
class LocalDataError extends StatelessWidget {
  final Object error;
  final bool isEn;
  final VoidCallback onRetry;
  const LocalDataError({super.key, required this.error, required this.isEn, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_rounded, size: 48, color: AppColors.rose),
              const SizedBox(height: 12),
              Text(
                '${isEn ? 'Could not read the data on this phone' : 'No se pudieron leer los datos del celular'}:\n'
                '${describeWithCode(error, isEn: isEn)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text(isEn ? 'Retry' : 'Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
