import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_routes.dart';
import '../constants/app_colors.dart';
import '../errors/error_messages.dart';
import '../utils/date_utils.dart';
import 'sync_controller.dart';
import '../../l10n/l10n.dart';

/// Estado de los datos guardados en el celular y botón para sincronizar.
class SyncStatusCard extends ConsumerStatefulWidget {
  const SyncStatusCard({super.key});

  @override
  ConsumerState<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends ConsumerState<SyncStatusCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(syncControllerProvider.notifier).refreshCounts());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(syncControllerProvider);
    final (texto, color) = switch (s.status) {
      SyncStatus.idle => (context.l10n.notSyncedSession, AppColors.lightTextSecondary),
      SyncStatus.syncing => (context.l10n.syncing, AppColors.primary),
      SyncStatus.complete => (context.l10n.completeMatchesServer, AppColors.emerald),
      SyncStatus.attention => (context.l10n.notEverythingWasAppliedSee, AppColors.rose),
      SyncStatus.mismatch => (context.l10n.doesNotMatchServer, AppColors.rose),
      SyncStatus.offline => (context.l10n.syncOfflineSaved, AppColors.lightTextSecondary),
      SyncStatus.error => (context.l10n.syncFailed, AppColors.rose),
    };
    final last = s.lastCompleteAt == null ? '—' : AppDateUtils.formatDateTimeString(DateTime.parse(s.lastCompleteAt!).toLocal().toIso8601String());
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto, key: const ValueKey('sync-estado'), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
            Text(
              '${context.l10n.lastCompleteSync}: $last\n'
              '${context.l10n.phone}: ${s.localMovements} ${context.l10n.movements}, '
              '${s.localDetails} ${context.l10n.lines}\n'
              '${context.l10n.pendingSend}: ${s.pendingOps} · '
              '${context.l10n.rejected}: ${s.rejectedOps} · '
              '${context.l10n.conflict}: ${s.conflictOps}',
              key: const ValueKey('sync-totales'),
              style: const TextStyle(fontSize: 12),
            ),
            if (s.status == SyncStatus.error && s.error != null) ...[
              const SizedBox(height: 6),
              Text(
                ErrorMessages.describe(s.error!, context.l10n) +
                    (ErrorMessages.codeOf(s.error!) != null ? ' (${ErrorMessages.codeOf(s.error!)})' : ''),
                style: const TextStyle(fontSize: 12, color: AppColors.rose),
              ),
            ],
            if (s.status == SyncStatus.mismatch && s.lastResult != null) ...[
              const SizedBox(height: 6),
              ...s.lastResult!.mismatches.map((m) => Text('• $m', style: const TextStyle(fontSize: 11, color: AppColors.rose))),
            ],
            if (s.status == SyncStatus.attention && s.lastPush != null) ...[
              const SizedBox(height: 6),
              ...s.lastPush!.issues.take(5).map((i) => Text(
                    '• #${i.seq} ${i.status}: ${ErrorMessages.forCode(i.code, i.message ?? '', context.l10n)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.rose),
                  )),
            ],
            const SizedBox(height: 10),
            if (s.pendingOps + s.needsAttention > 0)
              TextButton.icon(
                key: const ValueKey('ver-pendientes'),
                onPressed: () => context.push(AppRoutes.syncPending),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text(context.l10n.pendingRejected),
              ),
            OutlinedButton.icon(
              onPressed: s.status == SyncStatus.syncing ? null : () => ref.read(syncControllerProvider.notifier).sync(),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(context.l10n.syncNow),
            ),
          ],
        ),
      ),
    );
  }
}
