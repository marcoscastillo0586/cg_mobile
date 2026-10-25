import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../data/local_categories_repository.dart';
import '../../domain/category_item.dart';
import '../providers/categories_admin_notifier.dart';
import '../providers/categories_admin_state.dart';
import '../../../../l10n/l10n.dart';

class CategoriesAdminScreen extends ConsumerStatefulWidget {
  const CategoriesAdminScreen({super.key});

  @override
  ConsumerState<CategoriesAdminScreen> createState() => _CategoriesAdminScreenState();
}

class _CategoriesAdminScreenState extends ConsumerState<CategoriesAdminScreen> {
  @override
  void initState() {
    super.initState();
    // Con conexión trae primero lo que cambió en el servidor; sin conexión muestra lo guardado.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesAdminNotifierProvider);
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (syncFinished(prev, next)) ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias(silencioso: true);
    });
    final notifier = ref.read(categoriesAdminNotifierProvider.notifier);

    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: state.filtroEstado == key,
          onSelected: (_) => notifier.setFiltroEstado(key),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.categories),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarCategorias)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nueva-categoria'),
        onPressed: () => _nombre(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newCategory),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.cargarCategorias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.searchCategory,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: notifier.setBusqueda,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                chip('todas', '${context.l10n.all} (${state.categorias.length})'),
                const SizedBox(width: 8),
                chip('activas', '${context.l10n.active} (${state.activasCount})'),
                const SizedBox(width: 8),
                chip('inactivas', '${context.l10n.inactive2} (${state.inactivasCount})'),
              ]),
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CategoriesAdminState state) {
    if (state.status == CategoriesAdminStatus.loading && state.categorias.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == CategoriesAdminStatus.error && state.categorias.isEmpty) {
      final error = state.error!;
      final code = ErrorMessages.codeOf(error);
      return ListView(children: [
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
            onPressed: ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias,
            child: Text(context.l10n.retry),
          ),
        ),
      ]);
    }
    final lista = state.categoriasFiltradas;
    if (lista.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(context.l10n.noCategories)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _CategoryTile(item: lista[i], onAction: (a) => _accion(context, lista[i], a)),
    );
  }

  Future<void> _accion(BuildContext context, CategoryItem item, String accion) async {
    final notifier = ref.read(categoriesAdminNotifierProvider.notifier);
    switch (accion) {
      case 'edit':
        await _nombre(context, item);
      case 'toggle':
        final error = await notifier.run((r) => r.setActive(item.id, !item.active));
        if (context.mounted) {
          await reportLocalAction(context, ref, error,
              ok: item.active
                  ? (context.l10n.categoryDeactivated)
                  : (context.l10n.categoryActivated));
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.deleteCategory),
            content: Text(context.l10n.withoutMovementsDeletedMovementsDeactivated),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.delete)),
            ],
          ),
        );
        if (ok != true) return;
        final error = await notifier.run((r) => r.delete(item.id));
        if (context.mounted) {
          await reportLocalAction(context, ref, error, ok: context.l10n.categoryDeleted);
        }
    }
  }

  /// Alta (item null) o renombrar.
  Future<void> _nombre(BuildContext context, CategoryItem? item) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [item?.name ?? ''],
        builder: (ctx, c) => AlertDialog(
          title: Text(item == null ? (context.l10n.newCategory) : (context.l10n.renameCategory)),
          content: TextField(
            key: const ValueKey('categoria-nombre'),
            controller: c[0],
            maxLength: categoryNameMax,
            decoration: InputDecoration(labelText: context.l10n.name, counterText: ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
            TextButton(
                key: const ValueKey('categoria-guardar'),
                onPressed: () => Navigator.pop(ctx, c[0].text),
                child: Text(context.l10n.save)),
          ],
        ),
      ),
    );
    if (texto == null || !context.mounted) return;
    final error =
        await ref.read(categoriesAdminNotifierProvider.notifier).run((r) => item == null ? r.create(texto) : r.rename(item.id, texto));
    if (context.mounted) {
      await reportLocalAction(context, ref, error,
          ok: item == null ? (context.l10n.categoryCreated) : (context.l10n.categoryRenamed));
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryItem item;
  final ValueChanged<String> onAction;
  const _CategoryTile({required this.item, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.active ? 1 : 0.6,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.amber.withValues(alpha: 0.15),
            child: Text(
              item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.amberDark, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              '${item.movementsCount} ${context.l10n.movements2}',
              if (!item.active) (context.l10n.inactive3),
              if (item.isReserved) (context.l10n.reserved),
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: item.isReserved
              ? Tooltip(message: context.l10n.reserved2, child: const Icon(Icons.lock_outline_rounded, size: 20))
              : PopupMenuButton<String>(
                  key: ValueKey('menu-categoria-${item.name}'),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(context.l10n.rename)),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(item.active ? (context.l10n.deactivate) : (context.l10n.activate)),
                    ),
                    PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
                  ],
                ),
        ),
      ),
    );
  }
}
