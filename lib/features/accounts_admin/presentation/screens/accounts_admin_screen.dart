import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_avatar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
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
        onPressed: () => showNotAvailable(context, isEn: isEn),
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
      itemBuilder: (_, i) => _AccountTile(item: cuentas[i], isEn: isEn),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountItem item;
  final bool isEn;

  const _AccountTile({required this.item, required this.isEn});

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
                      '${item.movementsCount} ${isEn ? 'movements' : 'movimientos'}',
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
                onSelected: (_) => showNotAvailable(context, isEn: isEn),
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
