import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/entities/category_admin_entity.dart';
import '../providers/categories_admin_notifier.dart';
import '../providers/categories_admin_state.dart';
import '../widgets/category_form_dialog.dart';

class CategoriesAdminScreen extends ConsumerStatefulWidget {
  const CategoriesAdminScreen({super.key});

  @override
  ConsumerState<CategoriesAdminScreen> createState() => _CategoriesAdminScreenState();
}

class _CategoriesAdminScreenState extends ConsumerState<CategoriesAdminScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirFormulario({CategoryAdminEntity? categoria}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CategoryFormDialog(
        categoria: categoria,
        onGuardar: ({
          required String nombre,
          required bool activa,
        }) async {
          if (categoria == null) {
            return await ref
                .read(categoriesAdminNotifierProvider.notifier)
                .crearCategoria(nombre: nombre);
          } else {
            return await ref
                .read(categoriesAdminNotifierProvider.notifier)
                .editarCategoria(
                  idCategoria: categoria.idCategoria,
                  nombre: nombre,
                  activa: activa,
                );
          }
        },
      ),
    );
  }

  void _confirmarEliminacion(CategoryAdminEntity categoria) {
    if (categoria.cantidadMovimientos > 0) {
      AppFeedback.showError(
        context,
        'No es posible eliminar la categoría "${categoria.nombre}" porque tiene ${categoria.cantidadMovimientos} movimientos asociados.',
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 24),
            SizedBox(width: 10),
            Text('Eliminar Categoría'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar permanentemente la categoría "${categoria.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(categoriesAdminNotifierProvider.notifier)
                  .eliminarCategoria(categoria.idCategoria);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesAdminNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<CategoriesAdminState>(categoriesAdminNotifierProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        AppFeedback.showSuccess(context, next.successMessage!);
      }
    });

    final categorias = state.categoriasFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rubros y Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar categorías',
            onPressed: () {
              AppFeedback.light();
              ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Categoría'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias();
        },
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar categoría por nombre...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(categoriesAdminNotifierProvider.notifier).setBusqueda('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  ref.read(categoriesAdminNotifierProvider.notifier).setBusqueda(val);
                },
              ),
            ),

            // Filtro visual por estado: ["Todas", "Activas", "Inactivas"]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Todas (${state.categorias.length})'),
                      selected: state.filtroEstado == 'todas',
                      onSelected: (_) {
                        AppFeedback.selection();
                        ref.read(categoriesAdminNotifierProvider.notifier).setFiltroEstado('todas');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Activas (${state.activasCount})'),
                      selected: state.filtroEstado == 'activas',
                      selectedColor: AppColors.emerald.withValues(alpha: 0.2),
                      onSelected: (_) {
                        AppFeedback.selection();
                        ref.read(categoriesAdminNotifierProvider.notifier).setFiltroEstado('activas');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Inactivas (${state.inactivasCount})'),
                      selected: state.filtroEstado == 'inactivas',
                      selectedColor: AppColors.rose.withValues(alpha: 0.2),
                      onSelected: (_) {
                        AppFeedback.selection();
                        ref.read(categoriesAdminNotifierProvider.notifier).setFiltroEstado('inactivas');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Lista de categorías
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.status == CategoriesAdminStatus.loading && state.categorias.isEmpty) {
                    return ShimmerEffect(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 6,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, __) => Container(
                          height: 75,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  }

                  if (state.status == CategoriesAdminStatus.error && state.categorias.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.rose),
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage ?? 'Error al cargar categorías',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias();
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (categorias.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category_outlined, size: 54, color: AppColors.lightTextSecondary),
                          const SizedBox(height: 12),
                          Text(
                            state.busqueda.isNotEmpty
                                ? 'No se encontraron resultados para "${state.busqueda}"'
                                : 'No hay categorías para este filtro',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Crea una categoría con el botón "+" inferior',
                            style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                    itemCount: categorias.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = categorias[index];
                      final primeraLetra = item.nombre.isNotEmpty ? item.nombre[0].toUpperCase() : '?';
                      final canDelete = item.cantidadMovimientos == 0;

                      return Card(
                        elevation: item.activa ? 1.5 : 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: item.activa
                                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                : AppColors.rose.withValues(alpha: 0.3),
                            width: item.activa ? 1 : 1.2,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _abrirFormulario(categoria: item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                // Avatar con inicial
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (item.activa ? AppColors.amber : Colors.grey)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      primeraLetra,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: item.activa ? AppColors.amberDark : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nombre de categoría y etiqueta inactiva
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.nombre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: item.activa
                                                ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                                : Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!item.activa) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.rose.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'INACTIVA',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.rose,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Menú de acciones
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                                  onSelected: (val) {
                                    AppFeedback.selection();
                                    if (val == 'editar') {
                                      _abrirFormulario(categoria: item);
                                    } else if (val == 'estado') {
                                      ref
                                          .read(categoriesAdminNotifierProvider.notifier)
                                          .toggleEstado(idCategoria: item.idCategoria, nuevaActiva: !item.activa);
                                    } else if (val == 'eliminar') {
                                      _confirmarEliminacion(item);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 10),
                                          Text('Editar'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'estado',
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.activa ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(item.activa ? 'Desactivar' : 'Activar'),
                                        ],
                                      ),
                                    ),
                                    // Solo mostrar el botón de eliminar si la categoría tiene 0 movimientos asociados
                                    if (canDelete) ...[
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                                            SizedBox(width: 10),
                                            Text('Eliminar', style: TextStyle(color: AppColors.rose)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
