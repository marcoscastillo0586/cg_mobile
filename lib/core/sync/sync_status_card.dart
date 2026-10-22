import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../errors/error_messages.dart';
import '../utils/date_utils.dart';
import 'sync_controller.dart';

/// Estado de los datos guardados en el celular y botón para sincronizar.
class SyncStatusCard extends ConsumerStatefulWidget {
  final bool isEn;
  const SyncStatusCard({super.key, required this.isEn});

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
    final isEn = widget.isEn;
    final (texto, color) = switch (s.status) {
      SyncStatus.idle => (isEn ? 'Not synced in this session' : 'Sin sincronizar en esta sesión', AppColors.lightTextSecondary),
      SyncStatus.syncing => (isEn ? 'Syncing…' : 'Sincronizando…', AppColors.primary),
      SyncStatus.complete => (isEn ? 'Complete: matches the server' : 'Completa: coincide con el servidor', AppColors.emerald),
      SyncStatus.mismatch => (isEn ? 'Does not match the server' : 'No coincide con el servidor', AppColors.rose),
      SyncStatus.error => (isEn ? 'Sync failed' : 'Falló la sincronización', AppColors.rose),
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
              '${isEn ? 'Last complete sync' : 'Última sincronización completa'}: $last\n'
              '${isEn ? 'On this phone' : 'En este celular'}: ${s.localMovements} ${isEn ? 'movements' : 'comprobantes'}, '
              '${s.localDetails} ${isEn ? 'lines' : 'renglones'}',
              key: const ValueKey('sync-totales'),
              style: const TextStyle(fontSize: 12),
            ),
            if (s.status == SyncStatus.error && s.error != null) ...[
              const SizedBox(height: 6),
              Text(
                ErrorMessages.describe(s.error!, isEn: isEn) +
                    (ErrorMessages.codeOf(s.error!) != null ? ' (${ErrorMessages.codeOf(s.error!)})' : ''),
                style: const TextStyle(fontSize: 12, color: AppColors.rose),
              ),
            ],
            if (s.status == SyncStatus.mismatch && s.lastResult != null) ...[
              const SizedBox(height: 6),
              ...s.lastResult!.mismatches.map((m) => Text('• $m', style: const TextStyle(fontSize: 11, color: AppColors.rose))),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: s.status == SyncStatus.syncing ? null : () => ref.read(syncControllerProvider.notifier).sync(),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(isEn ? 'Sync now' : 'Sincronizar ahora'),
            ),
          ],
        ),
      ),
    );
  }
}
