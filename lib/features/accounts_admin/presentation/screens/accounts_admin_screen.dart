import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/local_accounts_repository.dart';
import '../../domain/account_item.dart';
import '../providers/accounts_admin_notifier.dart';
import '../providers/accounts_admin_state.dart';

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
    final isEn = ref.watch(settingsProvider).language == 'en';
    final notifier = ref.read(accountsAdminNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Accounts' : 'Cuentas y Medios de Pago'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarCuentas),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nueva-cuenta'),
        onPressed: () => _editar(context, null, isEn),
        icon: const Icon(Icons.add_rounded),
        label: Text(isEn ? 'New account' : 'Nueva cuenta'),
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
                    label: Text('${isEn ? 'All' : 'Todas'} (${state.cuentas.length})'),
                    selected: !state.mostrarSoloActivas,
                    onSelected: (_) {
                      if (state.mostrarSoloActivas) notifier.toggleFiltroSoloActivas();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('${isEn ? 'Active' : 'Activas'} (${state.activasCount})'),
                    selected: state.mostrarSoloActivas,
                    onSelected: (_) {
                      if (!state.mostrarSoloActivas) notifier.toggleFiltroSoloActivas();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(state, isEn)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AccountsAdminState state, bool isEn) {
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
            ErrorMessages.describe(error, isEn: isEn) + (code != null ? '\n($code)' : ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas,
              child: Text(isEn ? 'Retry' : 'Reintentar'),
            ),
          ),
        ],
      );
    }
    final cuentas = state.cuentasFiltradas;
    if (cuentas.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(isEn ? 'No accounts' : 'No hay cuentas registradas')),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: cuentas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AccountTile(item: cuentas[i], isEn: isEn, onAction: (a) => _accion(context, cuentas[i], a, isEn)),
    );
  }

  Future<void> _accion(BuildContext context, AccountItem item, String accion, bool isEn) async {
    final notifier = ref.read(accountsAdminNotifierProvider.notifier);
    switch (accion) {
      case 'edit':
        await _editar(context, item, isEn);
      case 'toggle':
        final error = await notifier.run((r) => r.setActive(item.id, !item.active));
        if (context.mounted) {
          await reportLocalAction(context, ref, error,
              ok: item.active
                  ? (isEn ? 'Account deactivated.' : 'Cuenta desactivada.')
                  : (isEn ? 'Account activated.' : 'Cuenta activada.'),
              isEn: isEn);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isEn ? 'Delete account?' : '¿Eliminar la cuenta?'),
            content: Text(isEn
                ? 'Without movements it is deleted; with movements it is deactivated.'
                : 'Sin movimientos se elimina; con movimientos se desactiva.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEn ? 'Cancel' : 'Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEn ? 'Delete' : 'Eliminar')),
            ],
          ),
        );
        if (ok != true) return;
        final error = await notifier.run((r) => r.delete(item.id));
        if (context.mounted) await reportLocalAction(context, ref, error, ok: isEn ? 'Account deleted.' : 'Cuenta eliminada.', isEn: isEn);
    }
  }

  /// Alta (item null) o edición de nombre/moneda. El ícono se elige al crear (la API de
  /// sincronización no lo cambia después).
  Future<void> _editar(BuildContext context, AccountItem? item, bool isEn) async {
    var moneda = item?.currency ?? Currency.ars;
    String? icono;
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [item?.name ?? ''],
        builder: (ctx, c) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(item == null ? (isEn ? 'New account' : 'Nueva cuenta') : (isEn ? 'Edit account' : 'Editar cuenta')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('cuenta-nombre'),
                    controller: c[0],
                    maxLength: accountNameMax,
                    decoration: InputDecoration(labelText: isEn ? 'Name' : 'Nombre'),
                  ),
                  DropdownButtonFormField<Currency>(
                    initialValue: moneda,
                    decoration: InputDecoration(labelText: isEn ? 'Currency' : 'Moneda'),
                    items: [for (final c in Currency.values) DropdownMenuItem(value: c, child: Text(c.code))],
                    onChanged: item != null && item.movementsCount > 0 ? null : (v) => setLocal(() => moneda = v ?? moneda),
                  ),
                  if (item != null && item.movementsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isEn ? 'Currency is locked: the account has movements.' : 'La moneda no se cambia: la cuenta tiene movimientos.',
                        style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                      ),
                    ),
                  if (item == null) ...[
                    const SizedBox(height: 12),
                    Text(isEn ? 'Icon' : 'Ícono', style: const TextStyle(fontWeight: FontWeight.w600)),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'Cancelar')),
              TextButton(
                  key: const ValueKey('cuenta-guardar'),
                  onPressed: () => Navigator.pop(ctx, c[0].text),
                  child: Text(isEn ? 'Save' : 'Guardar')),
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
          ok: item == null ? (isEn ? 'Account created.' : 'Cuenta creada.') : (isEn ? 'Account updated.' : 'Cuenta actualizada.'),
          isEn: isEn);
    }
  }
}

class _AccountTile extends StatelessWidget {
  final AccountItem item;
  final bool isEn;
  final ValueChanged<String> onAction;

  const _AccountTile({required this.item, required this.isEn, required this.onAction});

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
                        if (!item.active) _Badge(text: isEn ? 'Inactive' : 'Inactiva', color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.movementsCount} ${isEn ? 'movements' : 'movimientos'}${item.serverId == null ? (isEn ? ' · pending sync' : ' · sin sincronizar') : ''}',
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
                  PopupMenuItem(value: 'edit', child: Text(isEn ? 'Edit' : 'Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.active ? (isEn ? 'Deactivate' : 'Desactivar') : (isEn ? 'Activate' : 'Activar')),
                  ),
                  PopupMenuItem(value: 'delete', child: Text(isEn ? 'Delete' : 'Eliminar')),
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
