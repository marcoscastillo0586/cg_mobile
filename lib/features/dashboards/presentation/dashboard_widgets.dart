import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/utils/app_feedback.dart';
import '../../../l10n/l10n.dart';
import '../../../routes/app_routes.dart';
import '../../movements/presentation/local_write_feedback.dart';
import '../domain/dashboard.dart';
import 'dashboards_notifier.dart';

const _manage = 'manage';

/// Selector de dashboards habilitados (propios y compartidos), entre la campana y el ícono de gráficos.
class DashboardSelector extends ConsumerWidget {
  const DashboardSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardsNotifierProvider);
    final notifier = ref.read(dashboardsNotifierProvider.notifier);
    final current = notifier.current;
    return PopupMenuButton<Object>(
      key: const ValueKey('selector-dashboard'),
      icon: Icon(current?.shared == true ? Icons.group_outlined : Icons.dashboard_outlined),
      tooltip: context.l10n.chooseDashboard,
      onSelected: (value) async {
        AppFeedback.selection();
        if (value == _manage) {
          await context.push(AppRoutes.dashboardsAdmin);
          return;
        }
        if (value is! Dashboard || value.id == current?.id) return;
        // Antes de cambiar se envía lo pendiente del actual (con conexión): nada queda a medio guardar.
        await ref.read(syncControllerProvider.notifier).sync(force: false);
        await notifier.select(value);
      },
      itemBuilder: (context) => [
        for (final d in state.dashboards)
          CheckedPopupMenuItem<Object>(
            value: d,
            checked: d.id == current?.id,
            child: Text(
              '${notifier.label(d, context.l10n)}${d.shared ? ' · ${context.l10n.dashboardSharedTag}' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (state.dashboards.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem<Object>(value: _manage, child: Text(context.l10n.manageDashboards)),
      ],
    );
  }
}

/// Ventana para aceptar o rechazar una invitación recibida (aparece sola).
Future<void> showInvitationDialog(BuildContext context, WidgetRef ref, DashboardInvitation inv) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l.invitationTitle),
      content: Text(l.invitationBody(inv.inviterName, inv.inviterEmail, inv.dashboardName)),
      actions: [
        TextButton(
          key: const ValueKey('rechazar-invitacion'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () async {
            final error = await ref.read(dashboardsNotifierProvider.notifier).reject(inv);
            if (ctx.mounted) Navigator.pop(ctx);
            if (error != null && context.mounted) AppFeedback.showError(context, describeWithCode(error, l));
          },
          child: Text(l.rejectInvitation),
        ),
        FilledButton(
          key: const ValueKey('aceptar-invitacion'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () async {
            // Al aceptar se pasa al dashboard compartido (se recrea toda la pantalla).
            final error = await ref.read(dashboardsNotifierProvider.notifier).accept(inv);
            if (ctx.mounted) Navigator.pop(ctx);
            if (error != null && context.mounted) AppFeedback.showError(context, describeWithCode(error, l));
          },
          child: Text(l.acceptInvitation),
        ),
      ],
    ),
  );
}
