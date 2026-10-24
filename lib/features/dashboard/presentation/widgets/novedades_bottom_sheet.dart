import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../routes/app_routes.dart';
import '../../domain/entities/novedad_entity.dart';
import '../providers/novedades_notifier.dart';
import '../../../../l10n/l10n.dart';

class NovedadesBottomSheet extends ConsumerWidget {
  const NovedadesBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NovedadesBottomSheet(),
    );
  }

  String _obtenerTextoNovedad(NovedadEntity n, AppLocalizations l) {
    switch (n.tipo) {
      case NovedadTipo.cerca:
        return l.limitNearTop(n.titulo, n.porcentaje);
      case NovedadTipo.alcanzado:
        return l.limitReached(n.titulo, n.porcentaje);
      case NovedadTipo.vencido:
        return l.limitHasFinishedExpired(n.titulo);
    }
  }

  Color _obtenerColorTipo(NovedadTipo tipo) {
    switch (tipo) {
      case NovedadTipo.cerca:
        return AppColors.amber;
      case NovedadTipo.alcanzado:
        return AppColors.rose;
      case NovedadTipo.vencido:
        return AppColors.primary;
    }
  }

  IconData _obtenerIconoTipo(NovedadTipo tipo) {
    switch (tipo) {
      case NovedadTipo.cerca:
        return Icons.warning_amber_rounded;
      case NovedadTipo.alcanzado:
        return Icons.error_outline_rounded;
      case NovedadTipo.vencido:
        return Icons.event_busy_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(novedadesNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final novedades = state.novedades;

    final tituloPanel = context.l10n.notifications;
    final sinNovedadesTexto = context.l10n.noPendingNotifications;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  tituloPanel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Novedades
          Expanded(
            child: novedades.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            sinNovedadesTexto,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: novedades.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = novedades[index];
                      final color = _obtenerColorTipo(item.tipo);
                      final icon = _obtenerIconoTipo(item.tipo);
                      final texto = _obtenerTextoNovedad(item, context.l10n);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            AppFeedback.light();
                            ref
                                .read(novedadesNotifierProvider.notifier)
                                .marcarComoVista(item);

                            Navigator.of(context).pop();

                            // Navegar a la solapa de Límites y Presupuestos
                            final currentRoute = GoRouterState.of(context).matchedLocation;
                            if (currentRoute != AppRoutes.limitsAdmin) {
                              context.push(AppRoutes.limitsAdmin);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.vista
                                  ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                                  : color.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: item.vista
                                    ? Colors.transparent
                                    : color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        texto,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: item.vista ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
