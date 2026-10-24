import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/novedades_notifier.dart';
import 'novedades_bottom_sheet.dart';

class NotificationBellWidget extends ConsumerWidget {
  const NotificationBellWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novedadesNotifierProvider);
    final hasUnread = state.hasUnread;
    final dotColor = state.gravedadMaxColor;
    final isEn = ref.watch(settingsProvider).language == 'en';

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            hasUnread ? Icons.notifications_active_outlined : Icons.notifications_outlined,
            color: hasUnread ? null : Colors.grey,
          ),
          tooltip: isEn ? 'Notifications' : 'Novedades',
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
