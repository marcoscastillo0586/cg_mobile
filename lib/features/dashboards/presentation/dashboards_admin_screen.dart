import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dashboards/dashboard_switch.dart';
import '../../../core/utils/app_feedback.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../movements/presentation/local_write_feedback.dart';
import '../data/dashboards_repository.dart';
import '../domain/dashboard.dart';
import 'dashboards_notifier.dart';

typedef _Run = Future<bool> Function(Future<void> Function(DashboardsRepository repo) action, String ok);
typedef _Confirm = Future<bool> Function(String title, String message, String action);

/// Gestión de dashboards (docs/dashboards.md de CG): crear, renombrar, compartir por correo, integrantes,
/// quitar acceso, limpiar el principal, eliminar y salir. Requiere conexión (el servidor valida).
class DashboardsAdminScreen extends ConsumerStatefulWidget {
  const DashboardsAdminScreen({super.key});

  @override
  ConsumerState<DashboardsAdminScreen> createState() => _DashboardsAdminScreenState();
}

class _DashboardsAdminScreenState extends ConsumerState<DashboardsAdminScreen> {
  final _newName = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dashboardsNotifierProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  /// Ejecuta una acción del servidor, avisa el resultado traducido y recarga la lista.
  Future<bool> _run(Future<void> Function(DashboardsRepository repo) action, String ok) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action(ref.read(dashboardsRepositoryProvider));
      await ref.read(dashboardsNotifierProvider.notifier).refresh();
      if (mounted) AppFeedback.showSuccess(context, ok);
      return true;
    } catch (e) {
      debugPrint('[DASHBOARDS] No se completó la acción: $e');
      if (mounted) AppFeedback.showError(context, describeWithCode(e, context.l10n));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    if (await _run((r) => r.create(name), context.l10n.dashboardCreated(name))) _newName.clear();
  }

  Future<void> _leave(Dashboard d) async {
    final l = context.l10n;
    if (!await _confirm(l.leaveDashboard, l.confirmLeaveDashboard(d.name), l.leaveDashboard)) return;
    if (await _run((r) => r.leave(d.id), l.dashboardLeftMsg)) await DashboardSwitch.lost(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(dashboardsNotifierProvider);
    final notifier = ref.read(dashboardsNotifierProvider.notifier);
    final userId = ref.watch(authNotifierProvider.select((s) => s.user?.idUsuario));
    final own = state.dashboards.where((d) => d.ownerUserId == userId).toList();
    final shared = state.dashboards.where((d) => d.ownerUserId != userId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.dashboards)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.dashboardsNeedConnection, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(l.yourDashboards, style: Theme.of(context).textTheme.titleMedium),
          for (final d in own)
            _OwnDashboardCard(
              key: ValueKey('dashboard-${d.id}'),
              dashboard: d,
              label: notifier.label(d, l),
              run: _run,
              confirm: _confirm,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('nuevo-dashboard'),
                  controller: _newName,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: l.newDashboard, counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: _busy ? null : _create,
                child: Text(l.createDashboard),
              ),
            ],
          ),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l.sharedWithYou, style: Theme.of(context).textTheme.titleMedium),
            for (final d in shared)
              Card(
                child: ListTile(
                  title: Text(notifier.label(d, l)),
                  subtitle: Text(l.ownedBy(d.ownerName)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                        onPressed: () => notifier.select(d),
                        child: Text(l.openDashboard),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                        onPressed: _busy ? null : () => _leave(d),
                        child: Text(l.leaveDashboard),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OwnDashboardCard extends ConsumerStatefulWidget {
  final Dashboard dashboard;
  final String label;
  final _Run run;
  final _Confirm confirm;

  const _OwnDashboardCard({super.key, required this.dashboard, required this.label, required this.run, required this.confirm});

  @override
  ConsumerState<_OwnDashboardCard> createState() => _OwnDashboardCardState();
}

class _OwnDashboardCardState extends ConsumerState<_OwnDashboardCard> {
  final _email = TextEditingController();
  List<DashboardMember> _members = const [];

  Dashboard get d => widget.dashboard;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ref.read(dashboardsRepositoryProvider).members(d.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      // Sin conexión no se muestran los integrantes; el resto de la tarjeta sigue igual.
      debugPrint('[DASHBOARDS] No se pudieron cargar los integrantes: $e');
    }
  }

  Future<void> _rename() async {
    final l = context.l10n;
    final controller = TextEditingController(text: d.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: l.dashboardName),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == d.name) return;
    await widget.run((r) => r.rename(d.id, name), l.dashboardRenamed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    // Segunda línea solo con lo que el nombre no dice: que es el principal (si se llama distinto) y si está compartido.
    final details = [
      if (d.principal && d.name.trim().toLowerCase() != l.dashboardDefaultName) l.dashboardIsPrincipal,
      if (d.shared) l.dashboardSharedCount(d.membersCount),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(d.principal ? Icons.home_outlined : (d.shared ? Icons.group_outlined : Icons.dashboard_outlined),
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (details.isNotEmpty) Text(details.join(' · '), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('renombrar-${d.id}'),
                  tooltip: l.rename,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _rename,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('compartir-${d.id}'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: l.shareWithEmail),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                  onPressed: () async {
                    final email = _email.text.trim();
                    if (email.isEmpty) return;
                    if (await widget.run((r) => r.invite(d.id, email), l.invitationSent(email))) _email.clear();
                  },
                  child: Text(l.shareDashboard),
                ),
              ],
            ),
            if (_members.length > 1) ...[
              const SizedBox(height: 8),
              Text(l.dashboardMembers, style: const TextStyle(fontWeight: FontWeight.w600)),
              for (final m in _members)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.isOwner ? '${m.name} (${l.ownerTag})' : m.name),
                  subtitle: Text(m.email),
                  trailing: m.isOwner
                      ? null
                      : TextButton(
                          style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                          onPressed: () async {
                            if (!await widget.confirm(l.removeAccess, l.confirmRemoveMember(m.name, d.name), l.removeAccess)) return;
                            if (await widget.run((r) => r.removeMember(d.id, m.userId), l.accessRemovedMsg)) await _loadMembers();
                          },
                          child: Text(l.removeAccess),
                        ),
                ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 40), foregroundColor: Colors.red.shade700),
                onPressed: () async {
                  if (d.principal) {
                    if (!await widget.confirm(l.clearDashboard, l.confirmClearDashboard(d.name), l.clearDashboard)) return;
                    await widget.run((r) => r.clear(d.id), l.dashboardClearedMsg);
                  } else {
                    if (!await widget.confirm(l.deleteDashboard, l.confirmDeleteDashboard(d.name), l.deleteDashboard)) return;
                    // Se borra también su base local en el celular (y si era el elegido, vuelve al principal).
                    if (await widget.run((r) => r.remove(d.id), l.dashboardDeletedMsg)) await DashboardSwitch.lost(d.id);
                  }
                },
                child: Text(d.principal ? l.clearDashboard : l.deleteDashboard),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
