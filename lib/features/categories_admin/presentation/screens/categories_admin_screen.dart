import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/local_categories_repository.dart';
import '../../domain/category_item.dart';
import '../providers/categories_admin_notifier.dart';
import '../providers/categories_admin_state.dart';

class CategoriesAdminScreen extends ConsumerStatefulWidget {
  const CategoriesAdminScreen({super.key});

  @override
  ConsumerState<CategoriesAdminScreen> createState() => _CategoriesAdminScreenState();
}

class _CategoriesAdminScreenState extends ConsumerState<CategoriesAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesAdminNotifierProvider);
    final isEn = ref.watch(settingsProvider).language == 'en';
    final notifier = ref.read(categoriesAdminNotifierProvider.notifier);

    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: state.filtroEstado == key,
          onSelected: (_) => notifier.setFiltroEstado(key),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Categories' : 'Rubros y Categorías'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarCategorias)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nueva-categoria'),
        onPressed: () => _nombre(context, null, isEn),
        icon: const Icon(Icons.add_rounded),
        label: Text(isEn ? 'New category' : 'Nueva categoría'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.cargarCategorias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: isEn ? 'Search category' : 'Buscar categoría',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: notifier.setBusqueda,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                chip('todas', '${isEn ? 'All' : 'Todas'} (${state.categorias.length})'),
                const SizedBox(width: 8),
                chip('activas', '${isEn ? 'Active' : 'Activas'} (${state.activasCount})'),
                const SizedBox(width: 8),
                chip('inactivas', '${isEn ? 'Inactive' : 'Inactivas'} (${state.inactivasCount})'),
              ]),
            ),
            Expanded(child: _buildBody(state, isEn)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CategoriesAdminState state, bool isEn) {
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
          ErrorMessages.describe(error, isEn: isEn) + (code != null ? '\n($code)' : ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias,
            child: Text(isEn ? 'Retry' : 'Reintentar'),
          ),
        ),
      ]);
    }
    final lista = state.categoriasFiltradas;
    if (lista.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        Center(child: Text(isEn ? 'No categories' : 'No hay categorías')),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _CategoryTile(item: lista[i], isEn: isEn, onAction: (a) => _accion(context, lista[i], a, isEn)),
    );
  }

  Future<void> _accion(BuildContext context, CategoryItem item, String accion, bool isEn) async {
    final notifier = ref.read(categoriesAdminNotifierProvider.notifier);
    switch (accion) {
      case 'edit':
        await _nombre(context, item, isEn);
      case 'toggle':
        final error = await notifier.run((r) => r.setActive(item.id, !item.active));
        if (context.mounted) {
          await reportLocalAction(context, ref, error,
              ok: item.active
                  ? (isEn ? 'Category deactivated.' : 'Categoría desactivada.')
                  : (isEn ? 'Category activated.' : 'Categoría activada.'),
              isEn: isEn);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isEn ? 'Delete category?' : '¿Eliminar la categoría?'),
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
        if (context.mounted) {
          await reportLocalAction(context, ref, error, ok: isEn ? 'Category deleted.' : 'Categoría eliminada.', isEn: isEn);
        }
    }
  }

  /// Alta (item null) o renombrar.
  Future<void> _nombre(BuildContext context, CategoryItem? item, bool isEn) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [item?.name ?? ''],
        builder: (ctx, c) => AlertDialog(
          title: Text(item == null ? (isEn ? 'New category' : 'Nueva categoría') : (isEn ? 'Rename category' : 'Renombrar categoría')),
          content: TextField(
            key: const ValueKey('categoria-nombre'),
            controller: c[0],
            maxLength: categoryNameMax,
            decoration: InputDecoration(labelText: isEn ? 'Name' : 'Nombre', counterText: ''),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'Cancelar')),
            TextButton(
                key: const ValueKey('categoria-guardar'),
                onPressed: () => Navigator.pop(ctx, c[0].text),
                child: Text(isEn ? 'Save' : 'Guardar')),
          ],
        ),
      ),
    );
    if (texto == null || !context.mounted) return;
    final error =
        await ref.read(categoriesAdminNotifierProvider.notifier).run((r) => item == null ? r.create(texto) : r.rename(item.id, texto));
    if (context.mounted) {
      await reportLocalAction(context, ref, error,
          ok: item == null ? (isEn ? 'Category created.' : 'Categoría creada.') : (isEn ? 'Category renamed.' : 'Categoría renombrada.'),
          isEn: isEn);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryItem item;
  final bool isEn;
  final ValueChanged<String> onAction;
  const _CategoryTile({required this.item, required this.isEn, required this.onAction});

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
              '${item.movementsCount} ${isEn ? 'movements' : 'movimientos'}',
              if (!item.active) (isEn ? 'inactive' : 'inactiva'),
              if (item.isReserved) (isEn ? 'reserved' : 'reservada'),
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: item.isReserved
              ? Tooltip(message: isEn ? 'Reserved' : 'Reservada', child: const Icon(Icons.lock_outline_rounded, size: 20))
              : PopupMenuButton<String>(
                  key: ValueKey('menu-categoria-${item.name}'),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(isEn ? 'Rename' : 'Renombrar')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(item.active ? (isEn ? 'Deactivate' : 'Desactivar') : (isEn ? 'Activate' : 'Activar')),
                    ),
                    PopupMenuItem(value: 'delete', child: Text(isEn ? 'Delete' : 'Eliminar')),
                  ],
                ),
        ),
      ),
    );
  }
}
