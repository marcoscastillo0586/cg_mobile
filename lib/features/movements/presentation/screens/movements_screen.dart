import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/movements_skeleton.dart';
import '../../../../routes/app_routes.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/movement_entity.dart';
import '../providers/movement_list_notifier.dart';
import '../providers/movement_list_state.dart';
import '../widgets/edit_movement_dialog.dart';
import '../widgets/movement_card.dart';
import '../widgets/movement_summary_banner.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  final int? initialLugarId;
  final String? initialLugarNombre;

  const MovementsScreen({
    super.key,
    this.initialLugarId,
    this.initialLugarNombre,
  });

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(movementListNotifierProvider.notifier).cargarMovimientos(
            idLugar: widget.initialLugarId,
            nombreLugar: widget.initialLugarNombre,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(movementListNotifierProvider.notifier).setBusqueda(val);
      }
    });
  }

  void _seleccionarRangoFechas() async {
    final seleccion = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Filtrar rango de fechas',
    );

    if (seleccion != null) {
      final desde = DateFormat('yyyy-MM-dd').format(seleccion.start);
      final hasta = DateFormat('yyyy-MM-dd').format(seleccion.end);
      unawaited(ref.read(movementListNotifierProvider.notifier).cargarMovimientos(desde: desde, hasta: hasta));
    }
  }

  void _editarMovimiento(MovementEntity movement) async {
    AppFeedback.selection();
    if (movement.tipoMovimiento == 2) {
      final ok = await context.push<bool>(
        '${AppRoutes.expensesCreate}?edit_id=${movement.idMovimientoEnc}',
      );
      if (ok == true && mounted) {
        unawaited(ref.read(movementListNotifierProvider.notifier).cargarMovimientos());
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => EditMovementDialog(movement: movement),
      );
      if (ok == true && mounted) {
        unawaited(ref.read(movementListNotifierProvider.notifier).cargarMovimientos());
      }
    }
  }

  void _confirmarEliminar(int idMovimiento, String concepto) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Movimiento'),
        content: Text('¿Deseas eliminar permanentemente "$concepto"? Esta acción revertirá los saldos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(movementListNotifierProvider.notifier)
                  .eliminarMovimiento(idMovimiento);

              if (ok && mounted) {
                AppFeedback.showSuccess(context, 'Movimiento eliminado');
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementListNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final isEn = settings.language == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.nombreLugar != null && state.nombreLugar!.isNotEmpty
              ? 'Movimientos: ${state.nombreLugar}'
              : (isEn ? 'Transaction History' : 'Historial de Movimientos'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Filtrar por fecha',
            onPressed: _seleccionarRangoFechas,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
            onPressed: () {
              AppFeedback.light();
              ref.read(movementListNotifierProvider.notifier).cargarMovimientos();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await ref.read(movementListNotifierProvider.notifier).cargarMovimientos();
        },
        child: Column(
          children: [
            // Banner Resumen de Ingresos, Egresos y Balance
            if (state.resumen != null)
              MovementSummaryBanner(
                resumen: state.resumen!,
                desde: state.desde,
                hasta: state.hasta,
              ),

            // Campo de Búsqueda por Monto o Descripción con Indicador de Carga (Punto D)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isEn ? 'Search by description or amount...' : 'Buscar por descripción o monto...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: state.isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(movementListNotifierProvider.notifier).setBusqueda('');
                              },
                            )
                          : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.primary.withValues(alpha: 0.05),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Chips de Filtro activo
            if (state.hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    if (state.idLugar != null && state.idLugar! > 0)
                      Chip(
                        avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                        label: Text(state.nombreLugar ?? 'Cuenta #${state.idLugar}'),
                        onDeleted: () {
                          ref.read(movementListNotifierProvider.notifier).limpiarFiltroLugar();
                        },
                      ),
                    const SizedBox(width: 8),
                    if (state.desde != null || state.hasta != null)
                      Chip(
                        avatar: const Icon(Icons.date_range_outlined, size: 16),
                        label: const Text('Filtrado por fecha'),
                        onDeleted: () {
                          ref.read(movementListNotifierProvider.notifier).limpiarFiltroFechas();
                        },
                      ),
                  ],
                ),
              ),

            // Lista de Movimientos con Indicador de Carga Unificado de Búsqueda
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isSearching || (state.status == MovementListStatus.loading && state.movimientos.isEmpty)) {
                    return const MovementsSkeleton();
                  }

                  if (state.status == MovementListStatus.error && state.movimientos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.rose),
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage ?? 'Error al cargar el historial',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                ref.read(movementListNotifierProvider.notifier).cargarMovimientos();
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final listaFiltrada = state.movimientosFiltrados;

                  if (listaFiltrada.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 54,
                            color: isDark ? Colors.white30 : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.busqueda.isNotEmpty
                                ? (isEn
                                    ? 'No results found for "${state.busqueda}"'
                                    : 'No se encontraron resultados para "${state.busqueda}"')
                                : (isEn ? 'No movements recorded' : 'No hay movimientos registrados'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final item = listaFiltrada[index];

                      return MovementCard(
                        movement: item,
                        onEditar: () => _editarMovimiento(item),
                        onEliminar: () => _confirmarEliminar(item.idMovimientoEnc, item.conceptoGeneral),
                        onCargarDetalle: (id) => ref
                            .read(movementListNotifierProvider.notifier)
                            .obtenerDetalle(id),
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
