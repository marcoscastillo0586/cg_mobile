import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import 'dashboards_notifier.dart';

/// Dashboard compartido (docs/dashboards.md de CG): el dueño maneja todo; sin dashboard elegido todavía,
/// se es dueño del propio.
bool isDashboardOwner(WidgetRef ref) => ref.read(dashboardsNotifierProvider.notifier).current?.isOwner ?? true;

/// Un invitado edita lo que creó. Sin dato del servidor todavía (null) = creado en este celular.
bool canEditCreatedBy(WidgetRef ref, int? createdBy) =>
    isDashboardOwner(ref) || createdBy == null || createdBy == ref.read(authNotifierProvider).user?.idUsuario;
