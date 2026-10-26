import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dashboards/current_dashboard.dart';
import '../../../core/dashboards/dashboard_switch.dart';
import '../../../core/network/server_reachability.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../data/dashboards_repository.dart';
import '../domain/dashboard.dart';
import '../../../core/auth/current_account.dart';

class DashboardsState {
  final List<Dashboard> dashboards;
  final List<DashboardInvitation> invitations;
  final List<AppNotification> notifications;

  /// Error de la última carga que no es falta de conexión (se muestra traducido donde corresponde).
  final Object? error;

  const DashboardsState({this.dashboards = const [], this.invitations = const [], this.notifications = const [], this.error});

  DashboardsState copyWith({
    List<Dashboard>? dashboards,
    List<DashboardInvitation>? invitations,
    List<AppNotification>? notifications,
    Object? error,
    bool clearError = false,
  }) =>
      DashboardsState(
        dashboards: dashboards ?? this.dashboards,
        invitations: invitations ?? this.invitations,
        notifications: notifications ?? this.notifications,
        error: clearError ? null : (error ?? this.error),
      );
}

final dashboardsNotifierProvider = StateNotifierProvider<DashboardsNotifier, DashboardsState>((ref) {
  final userId = ref.watch(authNotifierProvider.select((s) => s.user?.idUsuario));
  return DashboardsNotifier(ref.watch(dashboardsRepositoryProvider), userId);
});

/// Dashboards del usuario, el elegido, invitaciones recibidas y avisos (docs/dashboards.md de CG).
/// Sin conexión usa la última lista guardada y no avisa nada.
class DashboardsNotifier extends StateNotifier<DashboardsState> {
  final DashboardsRepository _repository;
  final int? _userId;

  DashboardsNotifier(this._repository, this._userId) : super(const DashboardsState()) {
    unawaited(refresh());
  }

  /// El principal propio (base `cg_local.db`).
  bool isMyPrincipal(Dashboard d) => d.principal && d.ownerUserId == _userId;

  /// El dashboard que se está viendo (null hasta tener la lista).
  Dashboard? get current {
    final id = CurrentDashboard.id.value;
    for (final d in state.dashboards) {
      if (id == null ? isMyPrincipal(d) : d.id == id) return d;
    }
    return null;
  }

  /// Nombre para mostrar: si otro se llama igual, con el dueño entre paréntesis o "(tú)".
  String label(Dashboard d, AppLocalizations l) {
    final twin = state.dashboards.any((o) => o.id != d.id && o.name.trim().toLowerCase() == d.name.trim().toLowerCase());
    if (!twin) return d.name;
    return '${d.name} (${d.ownerUserId == _userId ? l.dashboardYou : d.ownerName})';
  }

  Future<void> select(Dashboard d) => DashboardSwitch.select(isMyPrincipal(d) ? null : d.id);

  /// Nombre del principal elegido sin conexión, propio de la cuenta conectada.
  static String get _pendingNameKey => CurrentAccount.key('pending_principal_name');

  /// Nombre del principal elegido en la primera vista. Se envía ya si hay conexión; si no, queda
  /// guardado y se envía en la próxima carga de la lista ([refresh]).
  Future<void> namePrincipal(String name) async {
    try {
      await _repository.savePendingName(_pendingNameKey, name);
    } catch (e) {
      debugPrint('[DASHBOARDS] No se pudo guardar el nombre pendiente: $e');
    }
    await _sendPendingName();
  }

  Future<void> _sendPendingName() async {
    try {
      final name = await _repository.readPendingName(_pendingNameKey);
      if (name == null || name.isEmpty) return;
      var mine = state.dashboards.where(isMyPrincipal).firstOrNull;
      if (mine == null) {
        final list = await _repository.list();
        if (mounted) state = state.copyWith(dashboards: list);
        mine = list.where(isMyPrincipal).firstOrNull;
      }
      if (mine == null) return;
      if (mine.name != name) {
        final renamed = await _repository.rename(mine.id, name);
        if (mounted) state = state.copyWith(dashboards: [for (final d in state.dashboards) d.id == renamed.id ? renamed : d]);
      }
      await _repository.savePendingName(_pendingNameKey, null);
    } catch (e) {
      _fail('nombre del dashboard', e);
    }
  }

  /// Lista (primero la guardada, después la del servidor), invitaciones y avisos.
  Future<void> refresh() async {
    try {
      final cached = await _repository.cached();
      if (mounted && state.dashboards.isEmpty && cached.isNotEmpty) state = state.copyWith(dashboards: cached);
    } catch (e) {
      debugPrint('[DASHBOARDS] No se pudo leer la lista guardada: $e');
    }
    if (ServerReachability.recentlyOffline) return;
    try {
      final previous = state.dashboards;
      final list = await _repository.list();
      if (!mounted) return;
      state = state.copyWith(dashboards: list, clearError: true);
      // Dashboards que ya no están (quitaron el acceso, salió o se eliminó): se borran sus datos del
      // celular; si era el elegido, se vuelve al principal.
      final gone = {for (final d in previous) d.id}..removeAll(list.map((d) => d.id));
      final chosen = CurrentDashboard.id.value;
      if (chosen != null && !list.any((d) => d.id == chosen)) gone.add(chosen);
      for (final id in gone) {
        await DashboardSwitch.lost(id);
      }
      await _sendPendingName();
      await loadInvitations();
      await loadNotifications();
    } catch (e) {
      _fail('lista', e);
    }
  }

  Future<void> loadInvitations() async {
    try {
      final invitations = await _repository.invitations();
      if (mounted) state = state.copyWith(invitations: invitations);
    } catch (e) {
      _fail('invitaciones', e);
    }
  }

  Future<void> loadNotifications() async {
    try {
      final notifications = await _repository.notifications();
      if (mounted) state = state.copyWith(notifications: notifications);
    } catch (e) {
      _fail('avisos', e);
    }
  }

  /// Acepta y pasa al dashboard compartido. Devuelve el error (para mostrarlo) o null.
  Future<Object?> accept(DashboardInvitation inv) async {
    try {
      final d = await _repository.accept(inv.id);
      state = state.copyWith(invitations: state.invitations.where((i) => i.id != inv.id).toList());
      await DashboardSwitch.select(d.id);
      return null;
    } catch (e) {
      debugPrint('[DASHBOARDS] No se pudo aceptar: $e');
      return e;
    }
  }

  Future<Object?> reject(DashboardInvitation inv) async {
    try {
      await _repository.reject(inv.id);
      if (mounted) state = state.copyWith(invitations: state.invitations.where((i) => i.id != inv.id).toList());
      return null;
    } catch (e) {
      debugPrint('[DASHBOARDS] No se pudo rechazar: $e');
      return e;
    }
  }

  /// Al tocar el aviso, desaparece.
  Future<Object?> markRead(AppNotification n) async {
    try {
      await _repository.markRead(n.id);
      if (mounted) state = state.copyWith(notifications: state.notifications.where((x) => x.id != n.id).toList());
      return null;
    } catch (e) {
      debugPrint('[DASHBOARDS] No se pudo marcar el aviso: $e');
      return e;
    }
  }

  void _fail(String what, Object e) {
    debugPrint('[DASHBOARDS] No se pudo cargar ($what): $e');
    // Sin conexión no se avisa: se sigue con lo guardado.
    if (mounted && !ServerReachability.isOfflineError(e)) state = state.copyWith(error: e);
  }
}
