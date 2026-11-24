import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/sync/reload_after_sync.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../../core/widgets/account_icon_picker.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../data/local_accounts_repository.dart';
import '../../domain/account_item.dart';
import '../providers/accounts_admin_notifier.dart';
import '../providers/accounts_admin_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../dashboards/presentation/dashboard_permissions.dart';
import '../../../../core/widgets/bottom_safe_area.dart';
import '../../../../core/widgets/load_error_view.dart';

class AccountsAdminScreen extends ConsumerStatefulWidget {
  const AccountsAdminScreen({super.key});

  @override
  ConsumerState<AccountsAdminScreen> createState() => _AccountsAdminScreenState();
}

class _AccountsAdminScreenState extends ConsumerState<AccountsAdminScreen> {
  @override
  void initState() {
    super.initState();
    // Con conexión trae primero lo que cambió en el servidor; sin conexión muestra lo guardado.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsAdminNotifierProvider);
    reloadAfterSync(ref, () => ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas(silencioso: true));
    final notifier = ref.read(accountsAdminNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accounts),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarCuentas),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nueva-cuenta'),
        onPressed: () => _editar(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newAccount),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.cargarCuentas,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('${context.l10n.all} (${state.cuentas.length})'),
                    selected: !state.mostrarSoloActivas,
                    onSelected: (_) {
                      if (state.mostrarSoloActivas) notifier.toggleFiltroSoloActivas();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('${context.l10n.active} (${state.activasCount})'),
                    selected: state.mostrarSoloActivas,
                    onSelected: (_) {
                      if (!state.mostrarSoloActivas) notifier.toggleFiltroSoloActivas();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AccountsAdminState state) {
    if (state.status == AccountsAdminStatus.loading && state.cuentas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == AccountsAdminStatus.error && state.cuentas.isEmpty) {
      final error = state.error!;
      return LoadErrorView(error: error, onRetry: ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas);
    }
    final cuentas = state.cuentasFiltradas;
    if (cuentas.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(context.l10n.noAccounts)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90).withBottomSafeArea(context),
      itemCount: cuentas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AccountTile(
        item: cuentas[i],
        canEdit: canEditCreatedBy(ref, cuentas[i].createdByUserId),
        canDelete: isDashboardOwner(ref),
        onAction: (a) => _accion(context, cuentas[i], a),
      ),
    );
  }


  Future<void> _accion(BuildContext context, AccountItem item, String accion) => switch (accion) {
        'edit' => _editar(context, item),
        'toggle' => _alternar(context, item),
        _ => _eliminar(context, item),
      };

  Future<void> _ejecutar(BuildContext context, Future<Object?> Function(LocalAccountsRepository r) accion, String ok) async {
    final error = await ref.read(accountsAdminNotifierProvider.notifier).run(accion);
    if (context.mounted) await reportLocalAction(context, ref, error, ok: ok);
  }

  Future<void> _alternar(BuildContext context, AccountItem item) => _ejecutar(
      context, (r) => r.setActive(item.id, !item.active), item.active ? context.l10n.accountDeactivated : context.l10n.accountActivated);

  Future<void> _eliminar(BuildContext context, AccountItem item) async {
    final l10n = context.l10n;
    if (!await confirmar(context, title: l10n.deleteAccount, message: l10n.withoutMovementsDeletedMovementsDeactivated, action: l10n.delete)) return;
    if (context.mounted) await _ejecutar(context, (r) => r.delete(item.id), l10n.accountDeleted);
  }

  /// Alta (item null) o edición de nombre, moneda e ícono.
  Future<void> _editar(BuildContext context, AccountItem? item) async {
    // Alta: se preselecciona la moneda principal.
    final principal = Currency.parse(ref.read(settingsProvider).defaultCurrency);
    final datos = await showDialog<_DatosCuenta>(context: context, builder: (_) => _CuentaDialog(item: item, monedaInicial: item?.currency ?? principal));
    if (datos == null || !context.mounted) return;
    final (:nombre, :moneda, :icono) = datos;
    await _ejecutar(
      context,
      (r) => item == null
          ? r.create(name: nombre, currency: moneda, iconRef: icono)
          : r.update(item.id, name: nombre, currency: item.movementsCount > 0 ? null : moneda, iconRef: icono),
      item == null ? context.l10n.accountCreated : context.l10n.accountUpdated,
    );
  }
}

typedef _DatosCuenta = ({String nombre, Currency moneda, String icono});

/// Nombre, moneda (fija si la cuenta ya tiene movimientos) e ícono de una cuenta.
class _CuentaDialog extends StatefulWidget {
  final AccountItem? item;
  final Currency monedaInicial;
  const _CuentaDialog({required this.item, required this.monedaInicial});

  @override
  State<_CuentaDialog> createState() => _CuentaDialogState();
}

class _CuentaDialogState extends State<_CuentaDialog> {
  late final _nombre = TextEditingController(text: widget.item?.name ?? '');
  late var _moneda = widget.monedaInicial;
  late var _icono = AccountIcons.normalize(widget.item?.iconRef);

  bool get _monedaFija => (widget.item?.movementsCount ?? 0) > 0;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.item == null ? l10n.newAccount : l10n.editAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('cuenta-nombre'),
              controller: _nombre,
              maxLength: accountNameMax,
              decoration: InputDecoration(labelText: l10n.name),
            ),
            DropdownButtonFormField<Currency>(
              key: const ValueKey('cuenta-moneda'),
              initialValue: _moneda,
              decoration: InputDecoration(labelText: l10n.currency),
              items: [for (final c in Currency.values) DropdownMenuItem(value: c, child: Text(c.code))],
              onChanged: _monedaFija ? null : (v) => setState(() => _moneda = v ?? _moneda),
            ),
            if (_monedaFija)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.currencyLockedAccountHasMovements, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
              ),
            const SizedBox(height: 12),
            Text(l10n.icon, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            AccountIconPicker(value: _icono, onChanged: (k) => setState(() => _icono = k)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          key: const ValueKey('cuenta-guardar'),
          onPressed: () => Navigator.pop(context, (nombre: _nombre.text, moneda: _moneda, icono: _icono)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Acciones del menú de una cuenta: editar y activar/desactivar quien puede editarla; eliminar, el dueño.
@visibleForTesting
List<String> accionesCuenta({required bool canEdit, required bool canDelete}) => [
      if (canEdit) ...['edit', 'toggle'],
      if (canDelete) 'delete',
    ];

class _AccountTile extends StatelessWidget {
  final AccountItem item;
  final ValueChanged<String> onAction;
  final bool canEdit;
  final bool canDelete;

  const _AccountTile({required this.item, required this.onAction, this.canEdit = true, this.canDelete = true});

  String _etiqueta(BuildContext context, String accion) => switch (accion) {
        'edit' => context.l10n.edit,
        'toggle' => item.active ? context.l10n.deactivate : context.l10n.activate,
        _ => context.l10n.delete,
      };

  @override
  Widget build(BuildContext context) {
    final acciones = accionesCuenta(canEdit: canEdit, canDelete: canDelete);
    final color = item.currency == Currency.usd ? AppColors.emerald : AppColors.primary;
    return Opacity(
      opacity: item.active ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              AccountAvatar(iconRef: item.iconRef),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Badge(text: item.currency.code, color: color),
                        if (!item.active) _Badge(text: context.l10n.inactive, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.movementsCount} ${context.l10n.movements2}${item.serverId == null ? (context.l10n.pendingSync) : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  Money.format(item.balanceCents, currency: item.currency),
                  key: ValueKey('saldo-cuenta-${item.id}'),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: item.balanceCents < 0 ? AppColors.rose : AppColors.emerald,
                  ),
                ),
              ),
              if (acciones.isNotEmpty)
                PopupMenuButton<String>(
                  key: ValueKey('menu-cuenta-${item.name}'),
                  onSelected: onAction,
                  itemBuilder: (_) => [for (final a in acciones) PopupMenuItem(value: a, child: Text(_etiqueta(context, a)))],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
