import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../sync/sync_service.dart';
import '../sync/sync_state.dart';
import '../utils/app_feedback.dart';

class SyncIconButton extends ConsumerWidget {
  const SyncIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncServiceProvider);
    final syncNotifier = ref.read(syncServiceProvider.notifier);

    if (syncState.status == SyncStatus.syncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        syncState.status == SyncStatus.offline
            ? Icons.cloud_off_rounded
            : (syncState.status == SyncStatus.error ? Icons.sync_problem_rounded : Icons.sync_rounded),
        color: syncState.status == SyncStatus.offline
            ? Colors.orange
            : (syncState.status == SyncStatus.error ? AppColors.rose : AppColors.primary),
      ),
      tooltip: syncState.message ?? 'Sincronizar datos con servidor',
      onPressed: () async {
        AppFeedback.selection();
        await syncNotifier.runFullSync();

        if (context.mounted) {
          final currentState = ref.read(syncServiceProvider);
          if (currentState.status == SyncStatus.success) {
            AppFeedback.showSuccess(context, 'Sincronizado con éxito con el servidor local');
          } else if (currentState.status == SyncStatus.offline) {
            AppFeedback.showError(context, 'Servidor no disponible (modo offline activo)');
          } else if (currentState.message != null) {
            AppFeedback.showError(context, currentState.message!);
          }
        }
      },
    );
  }
}
