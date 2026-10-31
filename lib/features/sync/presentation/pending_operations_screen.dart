import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Operaciones sin aplicar: pendientes de enviar, rechazadas (con el motivo) y en conflicto.
/// Se pueden corregir, descartar (revierte el saldo local) o, en conflicto, reintentar con mis cambios.
class PendingOperationsScreen extends ConsumerWidget {
  const PendingOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_unresolvedProvider);
    final syncing = ref.watch(syncControllerProvider.select((s) => s.status == SyncStatus.syncing));

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

    Future<void> confirmDiscard(OutboxEntry e) async {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.discard),
          content: Text(e.status == 'conflict'
              ? (context.l10n.serverVersionKeptChangeLost)
              : (context.l10n.removedPhoneLocalBalanceReverted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.discard2)),
          ],
        ),
      );
      if (yes == true && context.mounted) await run((r) => r.discard(e.seq), context.l10n.discarded);
    }

    Future<void> correct(OutboxEntry e) async {
      try {
        final source = await (await ref.read(outboxRepositoryProvider)).correction(e.seq);
        if (!context.mounted) return;
        final route = switch (source.type) { 2 => AppRoutes.expensesCreate, 1 => AppRoutes.incomesCreate, _ => AppRoutes.transfersCreate };
        await context.push(route, extra: source);
        ref.invalidate(_unresolvedProvider);
      } catch (err) {
        debugPrint('[PENDIENTES] No se pudo abrir la corrección: $err');
        if (context.mounted) AppFeedback.showError(context, describeWithCode(err, context.l10n));
      }
    }

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
                itemBuilder: (context, i) {
                  final e = items[i];
                  final (label, color) = switch (e.status) {
                    'rejected' => (context.l10n.rejected2, AppColors.rose),
                    'conflict' => (context.l10n.conflictServerVersionApplied, AppColors.amberDark),
                    _ => (context.l10n.pending2, AppColors.primary),
                  };
                  final motivo = e.errorCode == null ? null : ErrorMessages.forCode(e.errorCode, e.errorMessage ?? '', context.l10n);
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
                            Text(
                              // forCode ya agrega el código cuando no tiene traducción: no repetirlo.
                              '${context.l10n.reason}: $motivo'
                              '${e.errorCode == 'VALIDATION_ERROR' || motivo.contains('(${e.errorCode})') ? '' : ' (${e.errorCode})'}',
                              style: TextStyle(fontSize: 12, color: color),
                            ),
                          ],
                          Text('${context.l10n.attempts}: ${e.attempts}', style: const TextStyle(fontSize: 11)),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (e.canCorrect)
                                TextButton(onPressed: () => correct(e), child: Text(context.l10n.correct)),
                              if (e.canRetryMine)
                                TextButton(
                                  onPressed: () => run((r) => r.retryMine(e.seq), context.l10n.queuedAgainChanges),
                                  child: Text(context.l10n.retryMyChanges),
                                ),
                              if (e.canDiscard)
                                TextButton(
                                  onPressed: () => confirmDiscard(e),
                                  child: Text(e.status == 'conflict'
                                      ? (context.l10n.keepServerVersion)
                                      : (context.l10n.discard2)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
