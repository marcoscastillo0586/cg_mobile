import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/utils/app_feedback.dart';
import '../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../dashboard/presentation/providers/novedades_notifier.dart';
import '../../../l10n/l10n.dart';

/// Texto traducido del error con su código, si lo tiene.
String describeWithCode(Object error, AppLocalizations l) {
  final code = ErrorMessages.codeOf(error);
  return ErrorMessages.describe(error, l) + (code != null && code != 'VALIDATION_ERROR' ? ' ($code)' : '');
}

/// Después de guardar: se envía ya al servidor, detrás de lo pendiente. Si el servidor lo
/// rechaza por una regla de negocio, muestra el error y devuelve false (no queda guardado).
/// Sin conexión queda en la cola y se envía solo cuando vuelva, sin avisar.
Future<bool> afterLocalWrite(BuildContext context, WidgetRef ref, String what) async {
  final rejection = await ref.read(syncControllerProvider.notifier).sendNow();
  unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
  unawaited(ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
  if (!context.mounted) return rejection == null;
  if (rejection != null) {
    AppFeedback.showError(context, describeWithCode(rejection, context.l10n));
    return false;
  }
  AppFeedback.showSuccess(context, context.l10n.savedThing(what));
  return true;
}

/// Pantalla de error cuando el formulario no puede leer la base local.
class LocalDataError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const LocalDataError({super.key, required this.error, required this.onRetry});

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
                '${context.l10n.couldNotReadDataPhone}:\n'
                '${describeWithCode(error, context.l10n)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado de una alta/baja/cambio (cuentas, categorías, límites): muestra el error traducido
/// (validación local o rechazo del servidor, que no deja el cambio guardado) o confirma.
/// Sin conexión queda en la cola y se envía solo, sin avisar.
Future<bool> reportLocalAction(BuildContext context, WidgetRef ref, Object? error, {required String ok}) async {
  final problem = error ?? await ref.read(syncControllerProvider.notifier).sendNow();
  if (problem != null) {
    if (context.mounted) AppFeedback.showError(context, describeWithCode(problem, context.l10n));
    if (error == null) unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
    return false;
  }
  unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
  unawaited(ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
  if (context.mounted) AppFeedback.showSuccess(context, ok);
  return true;
}
