import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/movements_skeleton.dart';
import '../../../../routes/app_routes.dart';
import '../providers/movement_list_notifier.dart';
import '../providers/movement_list_state.dart';
import '../widgets/movement_card.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../core/widgets/bottom_safe_area.dart';
import '../../../../core/widgets/load_error_view.dart';

/// Terminó una sincronización que trajo movimientos nuevos o borrados: la lista se actualiza.
@visibleForTesting
bool trajoMovimientos(SyncState? prev, SyncState next) {
  final pulled = next.lastResult;
  return syncFinished(prev, next) && pulled != null && pulled.movementsApplied + pulled.deletedApplied > 0;
}

class MovementsScreen extends ConsumerStatefulWidget {
  final int? initialLugarId;
  final String? initialLugarNombre;

  const MovementsScreen({super.key, this.initialLugarId, this.initialLugarNombre});

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(movementListNotifierProvider.notifier).cargarMas();
      }
    });
    Future.microtask(() => ref
        .read(movementListNotifierProvider.notifier)
        .inicializar(idCuenta: widget.initialLugarId, nombreCuenta: widget.initialLugarNombre));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(movementListNotifierProvider.notifier).setBusqueda(val);
    });
  }

  Future<void> _seleccionarRango() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.l10n.dateRange,
    );
    if (r == null) return;
    final f = DateFormat('yyyy-MM-dd');
    await ref.read(movementListNotifierProvider.notifier).setRango(f.format(r.start), f.format(r.end));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementListNotifierProvider);
    final notifier = ref.read(movementListNotifierProvider.notifier);
    // La sincronización automática trajo movimientos nuevos o borrados: se actualiza la lista.
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (trajoMovimientos(prev, next)) notifier.cargarMovimientos(silencioso: true);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(state.nombreCuenta ?? (context.l10n.movements3)),
        actions: [
          IconButton(icon: const Icon(Icons.date_range_rounded), onPressed: () => _seleccionarRango()),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarMovimientos),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: context.l10n.searchTextAmount,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (state.hasFilters) _Filtros(state: state, notifier: notifier),
          if (state.status == MovementListStatus.loaded || state.movimientos.isNotEmpty) _Resumen(state: state),
          Expanded(child: _lista(state)),
        ],
      ),
    );
  }

  Widget _lista(MovementListState state) {
    if (state.isLoading && state.movimientos.isEmpty) return const MovementsSkeleton();
    final error = state.error;
    if (state.status == MovementListStatus.error && state.movimientos.isEmpty && error != null) {
      return LoadErrorView(error: error, onRetry: ref.read(movementListNotifierProvider.notifier).cargarMovimientos, top: 60);
    }
    if (state.movimientos.isEmpty) {
      return Center(child: Text(context.l10n.noMovements));
    }
    return RefreshIndicator(
      onRefresh: ref.read(movementListNotifierProvider.notifier).cargarMovimientos,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24).withBottomSafeArea(context),
        itemCount: state.movimientos.length + 1,
        itemBuilder: (_, i) {
          if (i == state.movimientos.length) {
            if (state.loadingMore) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(ErrorMessages.describe(error, context.l10n),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rose)),
              );
            }
            return const SizedBox(height: 8);
          }
          final item = state.movimientos[i];
          final userId = ref.read(authNotifierProvider).user?.idUsuario;
          return MovementCard(
            item: item,
            // Siempre se ve quién lo cargó; solo esa persona lo edita o lo borra (sin dato del
            // servidor todavía = cargado en este celular).
            canEdit: item.createdByUserId == null || item.createdByUserId == userId,
            // Edición y borrado por la outbox (funcionan sin conexión; el envío lo hace el sincronizador).
            onEditar: () async {
              await context.push(AppRoutes.movementEdit(item.id));
              if (context.mounted) await ref.read(movementListNotifierProvider.notifier).cargarMovimientos();
            },
            onEliminar: () async {
              await context.push(AppRoutes.movementEdit(item.id, askDelete: true));
              if (context.mounted) await ref.read(movementListNotifierProvider.notifier).cargarMovimientos();
            },
          );
        },
      ),
    );
  }
}

/// Filtros activos (cuenta, rango de fechas), cada uno con su cruz para quitarlo.
class _Filtros extends StatelessWidget {
  final MovementListState state;
  final MovementListNotifier notifier;
  const _Filtros({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final cuenta = state.nombreCuenta;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        if (cuenta != null) InputChip(label: Text(cuenta), onDeleted: notifier.limpiarFiltroCuenta),
        if (state.hayRango) ...[
          const SizedBox(width: 8),
          InputChip(
            label: Text('${AppDateUtils.formatDateString(state.desde)} – ${AppDateUtils.formatDateString(state.hasta)}'),
            onDeleted: notifier.limpiarFiltroFechas,
          ),
        ],
      ]),
    );
  }
}

/// Con filtros, cuántos y su total; sin filtros, cuántos movimientos hay.
class _Resumen extends StatelessWidget {
  final MovementListState state;
  const _Resumen({required this.state});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          state.hasFilters
              ? '${state.total} ${context.l10n.results} · Total ${Money.format(state.filteredTotalCents)}'
              : context.l10n.lastMovements(state.total),
          key: const ValueKey('movimientos-resumen'),
          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary, fontWeight: FontWeight.w600),
        ),
      );
}
