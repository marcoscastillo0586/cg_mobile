import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/sync/outbox_repository.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/utils/app_feedback.dart';
import '../../../routes/app_routes.dart';
import '../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../movements/presentation/local_write_feedback.dart';
import '../../../l10n/l10n.dart';
import '../../../core/widgets/bottom_safe_area.dart';

final _unresolvedProvider = FutureProvider.autoDispose<List<OutboxEntry>>((ref) async {
  ref.watch(syncControllerProvider.select((s) => (s.status, s.pendingOps, s.rejectedOps, s.conflictOps)));
  return (await ref.watch(outboxRepositoryProvider)).unresolved();
});

/// "Motivo: …" de una operación rechazada o en conflicto; null sin código. forCode ya agrega el código cuando
/// no tiene traducción, y la validación trae su texto: en esos casos no se repite.
@visibleForTesting
String? motivoDe(OutboxEntry e, AppLocalizations l) {
  final code = e.errorCode;
  if (code == null) return null;
  final motivo = ErrorMessages.forCode(code, e.errorMessage ?? '', l);
  final sufijo = code == 'VALIDATION_ERROR' || motivo.contains('($code)') ? '' : ' ($code)';
  return '${l.reason}: $motivo$sufijo';
}

/// Formulario que corrige un comprobante rechazado según su tipo (2 egreso, 1 ingreso, si no transferencia).
@visibleForTesting
String rutaDeCorreccion(int type) => switch (type) { 2 => AppRoutes.expensesCreate, 1 => AppRoutes.incomesCreate, _ => AppRoutes.transfersCreate };

/// Operaciones sin aplicar: pendientes de enviar, rechazadas (con el motivo) y en conflicto.
/// Se pueden corregir, descartar (revierte el saldo local) o, en conflicto, reintentar con mis cambios.
class PendingOperationsScreen extends ConsumerWidget {
  const PendingOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_unresolvedProvider);
    final syncing = ref.watch(syncControllerProvider.select((s) => s.status == SyncStatus.syncing));
    final acciones = _Acciones(context, ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.pendingRejected),
        actions: [
          IconButton(
            tooltip: context.l10n.syncNow,
            onPressed: syncing ? null : () => ref.read(syncControllerProvider.notifier).sync(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(describeWithCode(e, context.l10n)))),
        data: (items) => items.isEmpty
            ? Center(child: Text(context.l10n.nothingPendingEverythingWasApplied))
            : ListView.separated(
                padding: const EdgeInsets.all(16).withBottomSafeArea(context),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OperacionCard(entry: items[i], acciones: acciones),
              ),
      ),
    );
  }
}

/// Corregir, reintentar mis cambios y descartar, con aviso del resultado.
class _Acciones {
  final BuildContext context;
  final WidgetRef ref;
  const _Acciones(this.context, this.ref);

  Future<void> run(Future<void> Function(OutboxRepository repo) action, String ok) async {
    try {
      await action(await ref.read(outboxRepositoryProvider));
      await ref.read(syncControllerProvider.notifier).refreshCounts();
      ref.invalidate(_unresolvedProvider);
      await ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
      if (context.mounted) AppFeedback.showSuccess(context, ok);
    } catch (e) {
      debugPrint('[PENDIENTES] Acción fallida: $e');
      if (context.mounted) AppFeedback.showError(context, describeWithCode(e, context.l10n));
    }
  }

  Future<void> discard(OutboxEntry e) async {
    final l10n = context.l10n;
    final yes = await confirmar(context,
        title: l10n.discard,
        message: e.status == 'conflict' ? l10n.serverVersionKeptChangeLost : l10n.removedPhoneLocalBalanceReverted,
        action: l10n.discard2);
    if (yes && context.mounted) await run((r) => r.discard(e.seq), l10n.discarded);
  }

  Future<void> retryMine(OutboxEntry e) => run((r) => r.retryMine(e.seq), context.l10n.queuedAgainChanges);

  Future<void> correct(OutboxEntry e) async {
    try {
      final source = await (await ref.read(outboxRepositoryProvider)).correction(e.seq);
      if (!context.mounted) return;
      await context.push(rutaDeCorreccion(source.type), extra: source);
      ref.invalidate(_unresolvedProvider);
    } catch (err) {
      debugPrint('[PENDIENTES] No se pudo abrir la corrección: $err');
      if (context.mounted) AppFeedback.showError(context, describeWithCode(err, context.l10n));
    }
  }
}

class _OperacionCard extends StatelessWidget {
  final OutboxEntry entry;
  final _Acciones acciones;
  const _OperacionCard({required this.entry, required this.acciones});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = entry;
    final (label, color) = switch (e.status) {
      'rejected' => (l10n.rejected2, AppColors.rose),
      'conflict' => (l10n.conflictServerVersionApplied, AppColors.amberDark),
      _ => (l10n.pending2, AppColors.primary),
    };
    final motivo = motivoDe(e, l10n);
    return Card(
      key: ValueKey('op-${e.seq}'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label · #${e.seq}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(e.description),
            if (motivo != null) ...[
              const SizedBox(height: 4),
              Text(motivo, style: TextStyle(fontSize: 12, color: color)),
            ],
            Text('${l10n.attempts}: ${e.attempts}', style: const TextStyle(fontSize: 11)),
            Wrap(
              spacing: 8,
              children: [
                if (e.canCorrect) TextButton(onPressed: () => acciones.correct(e), child: Text(l10n.correct)),
                if (e.canRetryMine) TextButton(onPressed: () => acciones.retryMine(e), child: Text(l10n.retryMyChanges)),
                if (e.canDiscard)
                  TextButton(
                    onPressed: () => acciones.discard(e),
                    child: Text(e.status == 'conflict' ? l10n.keepServerVersion : l10n.discard2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
