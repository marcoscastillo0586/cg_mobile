import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/entities/expense_limit_admin_entity.dart';
import '../providers/limits_admin_notifier.dart';
import '../providers/limits_admin_state.dart';

class LimitsAdminScreen extends ConsumerStatefulWidget {
  const LimitsAdminScreen({super.key});

  @override
  ConsumerState<LimitsAdminScreen> createState() => _LimitsAdminScreenState();
}

class _LimitsAdminScreenState extends ConsumerState<LimitsAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(limitsAdminNotifierProvider.notifier).cargarLimites();
    });
  }

  // Alta y edición de presupuestos: con la cola de sincronización (etapa 8).
  void _abrirFormulario({ExpenseLimitAdminEntity? limit}) {
    showNotAvailable(context, isEn: false);
  }

  void _confirmarRenovacion(ExpenseLimitAdminEntity limit) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.update_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Renovar Presupuesto'),
          ],
        ),
        content: Text(
          '¿Deseas renovar el período del límite para "${limit.categoriasNombres}" por 1 mes adicional?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              AppFeedback.selection();
              await ref
                  .read(limitsAdminNotifierProvider.notifier)
                  .renovarLimite(limit.idLimiteGasto);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacion(ExpenseLimitAdminEntity limit) {
    final montoStr = AppCurrencyUtils.format(limit.montoLimite, symbol: '\$');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 24),
            SizedBox(width: 10),
            Text('Eliminar Límite'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar permanentemente el límite de $montoStr para "${limit.categoriasNombres}"?',
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
                  .read(limitsAdminNotifierProvider.notifier)
                  .eliminarLimite(limit.idLimiteGasto);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Punto 2.3: Mostrar "Renovar (+1 mes)" solo a partir del día siguiente al vencimiento
  bool _debeMostrarRenovacion(ExpenseLimitAdminEntity item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hastaDate = DateTime(item.hasta.year, item.hasta.month, item.hasta.day);
    return today.isAfter(hastaDate);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(limitsAdminNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    ref.listen<LimitsAdminState>(limitsAdminNotifierProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        AppFeedback.showSuccess(context, next.successMessage!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Límites y Presupuestos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
            onPressed: () {
              AppFeedback.light();
              ref.read(limitsAdminNotifierProvider.notifier).cargarLimites();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Límite'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await ref.read(limitsAdminNotifierProvider.notifier).cargarLimites();
        },
        child: CustomScrollView(
          slivers: [
            // Resumen Global de Presupuestos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildResumenCard(state, isDark),
              ),
            ),

            // Filtros de Estado (Punto 2.4: Sin input de búsqueda)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('todos', 'Todos (${state.limits.length})', state),
                      const SizedBox(width: 8),
                      _buildFilterChip('activos', 'En Curso (${state.activosCount})', state),
                      const SizedBox(width: 8),
                      _buildFilterChip('excedidos', 'Excedidos (${state.excedidosCount})', state),
                      const SizedBox(width: 8),
                      _buildFilterChip('vencidos', 'Vencidos (${state.vencidosCount})', state),
                    ],
                  ),
                ),
              ),
            ),

            // Lista de Tarjetas de Presupuestos
            if (state.status == LimitsAdminStatus.loading && state.limits.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerEffect(
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    childCount: 4,
                  ),
                ),
              )
            else if (state.limitsFiltrados.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.filtroEstado != 'todos'
                              ? 'No se encontraron límites con ese filtro'
                              : 'No tienes presupuestos configurados',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea topes mensuales para controlar tus gastos y recibir alertas de consumo.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _abrirFormulario(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crear Primer Límite'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final item = state.limitsFiltrados[index];
                      return _buildLimitCard(item, isDark, theme);
                    },
                    childCount: state.limitsFiltrados.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard(LimitsAdminState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.primary.withValues(alpha: 0.25), AppColors.emerald.withValues(alpha: 0.15)]
              : [AppColors.primary.withValues(alpha: 0.12), AppColors.emerald.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Presupuesto Mensual Activo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.lightTextSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.porcentajeGlobal.toStringAsFixed(1)}% Usado',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricColumn('Total Topes', AppCurrencyUtils.format(state.totalPresupuestado, symbol: '\$')),
              _metricColumn('Gastado', AppCurrencyUtils.format(state.totalConsumido, symbol: '\$'), color: AppColors.rose),
              _metricColumn('Restante', AppCurrencyUtils.format(state.totalResto, symbol: '\$'), color: state.totalResto < 0 ? AppColors.rose : AppColors.emerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filtroKey, String label, LimitsAdminState state) {
    final isSelected = state.filtroEstado == filtroKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      onSelected: (_) {
        AppFeedback.selection();
        ref.read(limitsAdminNotifierProvider.notifier).setFiltroEstado(filtroKey);
      },
    );
  }

  Widget _buildLimitCard(ExpenseLimitAdminEntity item, bool isDark, ThemeData theme) {
    final badge = _buildStatusBadge(item);
    final rangoFechas = '${AppDateUtils.formatDate(item.desde)} al ${AppDateUtils.formatDate(item.hasta)}';

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.excedido
              ? AppColors.rose.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.categoriasNombres.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 13, color: AppColors.lightTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.lugaresNombres,
                    style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.lightTextSecondary),
                const SizedBox(width: 4),
                Text(
                  rangoFechas,
                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Barra de progreso y consumido vs límite
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Consumido', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      AppCurrencyUtils.format(item.montoConsumido, symbol: '\$'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Tope Límite', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      AppCurrencyUtils.format(item.montoLimite, symbol: '\$'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: item.factorUso,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.excedido ? AppColors.rose : AppColors.emerald,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.vencido
                      ? 'Período finalizado'
                      : '${item.diasRestantes} días restantes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.vencido ? AppColors.rose : AppColors.lightTextSecondary,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.excedido ? 'Exceso' : 'Disponible',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      AppCurrencyUtils.format(item.resto.abs(), symbol: '\$'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: item.excedido ? AppColors.rose : AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Acciones: Renovar, Editar, Eliminar (Punto 2.3: Solo si ya venció / desde el día siguiente)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_debeMostrarRenovacion(item)) ...[
                  TextButton.icon(
                    onPressed: () => _confirmarRenovacion(item),
                    icon: const Icon(Icons.update_rounded, size: 16),
                    label: const Text('Renovar (+1 mes)', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editar monto',
                  onPressed: () {
                    AppFeedback.selection();
                    _abrirFormulario(limit: item);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                  tooltip: 'Eliminar límite',
                  onPressed: () => _confirmarEliminacion(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ExpenseLimitAdminEntity item) {
    if (item.vencido) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'VENCIDO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
    if (item.excedido) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'EXCEDIDO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rose),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'EN CURSO',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald),
      ),
    );
  }
}
