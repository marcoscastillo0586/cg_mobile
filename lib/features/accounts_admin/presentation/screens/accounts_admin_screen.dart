import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../data/local_accounts_repository.dart';
import '../../domain/account_item.dart';
import '../providers/accounts_admin_notifier.dart';
import '../providers/accounts_admin_state.dart';
import '../../../../l10n/l10n.dart';

class AccountsAdminScreen extends ConsumerStatefulWidget {
  const AccountsAdminScreen({super.key});

  @override
  ConsumerState<AccountsAdminScreen> createState() => _AccountsAdminScreenState();
}

class _AccountsAdminScreenState extends ConsumerState<AccountsAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsAdminNotifierProvider);
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
      final code = ErrorMessages.codeOf(error);
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.rose),
          const SizedBox(height: 12),
          Text(
            ErrorMessages.describe(error, context.l10n) + (code != null ? '\n($code)' : ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas,
              child: Text(context.l10n.retry),
            ),
          ),
        ],
      );
    }
    final cuentas = state.cuentasFiltradas;
    if (cuentas.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(context.l10n.noAccounts)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: cuentas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AccountTile(item: cuentas[i], onAction: (a) => _accion(context, cuentas[i], a)),
    );
  }

  Future<void> _accion(BuildContext context, AccountItem item, String accion) async {
    final notifier = ref.read(accountsAdminNotifierProvider.notifier);
    switch (accion) {
      case 'edit':
        await _editar(context, item);
      case 'toggle':
        final error = await notifier.run((r) => r.setActive(item.id, !item.active));
        if (context.mounted) {
          await reportLocalAction(context, ref, error,
              ok: item.active
                  ? (context.l10n.accountDeactivated)
                  : (context.l10n.accountActivated));
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.deleteAccount),
            content: Text(context.l10n.withoutMovementsDeletedMovementsDeactivated),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.delete)),
            ],
          ),
        );
        if (ok != true) return;
        final error = await notifier.run((r) => r.delete(item.id));
        if (context.mounted) await reportLocalAction(context, ref, error, ok: context.l10n.accountDeleted);
    }
  }

  /// Alta (item null) o edición de nombre/moneda. El ícono se elige al crear (la API de
  /// sincronización no lo cambia después).
  Future<void> _editar(BuildContext context, AccountItem? item) async {
    var moneda = item?.currency ?? Currency.ars;
    String? icono;
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [item?.name ?? ''],
        builder: (ctx, c) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(item == null ? (context.l10n.newAccount) : (context.l10n.editAccount)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('cuenta-nombre'),
                    controller: c[0],
                    maxLength: accountNameMax,
                    decoration: InputDecoration(labelText: context.l10n.name),
                  ),
                  DropdownButtonFormField<Currency>(
                    initialValue: moneda,
                    decoration: InputDecoration(labelText: context.l10n.currency),
                    items: [for (final c in Currency.values) DropdownMenuItem(value: c, child: Text(c.code))],
                    onChanged: item != null && item.movementsCount > 0 ? null : (v) => setLocal(() => moneda = v ?? moneda),
                  ),
                  if (item != null && item.movementsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.l10n.currencyLockedAccountHasMovements,
                        style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                      ),
                    ),
                  if (item == null) ...[
                    const SizedBox(height: 12),
                    Text(context.l10n.icon, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final e in AccountIcons.byKey.entries)
                          ChoiceChip(
                            key: ValueKey('icono-${e.key}'),
                            label: Icon(e.value, size: 20),
                            selected: icono == e.key,
                            onSelected: (_) => setLocal(() => icono = icono == e.key ? null : e.key),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
              TextButton(
                  key: const ValueKey('cuenta-guardar'),
                  onPressed: () => Navigator.pop(ctx, c[0].text),
                  child: Text(context.l10n.save)),
            ],
          ),
        ),
      ),
    );
    if (texto == null || !context.mounted) return;
    final notifier = ref.read(accountsAdminNotifierProvider.notifier);
    final error = await notifier.run((r) => item == null
        ? r.create(name: texto, currency: moneda, iconRef: icono)
        : r.update(item.id, name: texto, currency: item.movementsCount > 0 ? null : moneda));
    if (context.mounted) {
      await reportLocalAction(context, ref, error,
          ok: item == null ? (context.l10n.accountCreated) : (context.l10n.accountUpdated));
    }
  }
}

class _AccountTile extends StatelessWidget {
  final AccountItem item;
  final ValueChanged<String> onAction;

  const _AccountTile({required this.item, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final color = item.currency == Currency.usd ? AppColors.emerald : AppColors.primary;
    return Opacity(
      opacity: item.active ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              AccountAvatar(imageUrl: item.imageUrl, iconRef: item.iconRef, currency: item.currency),
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
              PopupMenuButton<String>(
                key: ValueKey('menu-cuenta-${item.name}'),
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.active ? (context.l10n.deactivate) : (context.l10n.activate)),
                  ),
                  PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
                ],
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
