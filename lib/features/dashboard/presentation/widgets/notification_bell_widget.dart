import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_feedback.dart';
import '../providers/novedades_notifier.dart';
import 'novedades_bottom_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../dashboards/presentation/dashboards_notifier.dart';

class NotificationBellWidget extends ConsumerWidget {
  const NotificationBellWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novedadesNotifierProvider);
    // Avisos del servidor (aceptó / rechazó una invitación) también cuentan como no leídos.
    final avisos = ref.watch(dashboardsNotifierProvider.select((s) => s.notifications.length));
    final hasUnread = state.hasUnread || avisos > 0;
    final dotColor = state.hasUnread ? state.gravedadMaxColor : Theme.of(context).colorScheme.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            hasUnread ? Icons.notifications_active_outlined : Icons.notifications_outlined,
            color: hasUnread ? null : Colors.grey,
          ),
          tooltip: context.l10n.notifications,
          onPressed: () {
            AppFeedback.light();
            NovedadesBottomSheet.show(context);
          },
        ),
        if (hasUnread)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
