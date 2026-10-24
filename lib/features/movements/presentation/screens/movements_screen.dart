import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/movements_skeleton.dart';
import '../../../../routes/app_routes.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/movement_list_notifier.dart';
import '../providers/movement_list_state.dart';
import '../widgets/movement_card.dart';

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

  Future<void> _seleccionarRango(bool isEn) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isEn ? 'Date range' : 'Rango de fechas',
    );
    if (r == null) return;
    final f = DateFormat('yyyy-MM-dd');
    await ref.read(movementListNotifierProvider.notifier).setRango(f.format(r.start), f.format(r.end));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementListNotifierProvider);
    final isEn = ref.watch(settingsProvider).language == 'en';
    final notifier = ref.read(movementListNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.nombreCuenta ?? (isEn ? 'Movements' : 'Movimientos')),
        actions: [
          IconButton(icon: const Icon(Icons.date_range_rounded), onPressed: () => _seleccionarRango(isEn)),
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
                hintText: isEn ? 'Search by text or amount' : 'Buscar por texto o monto',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (state.hasFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                if (state.nombreCuenta != null)
                  InputChip(label: Text(state.nombreCuenta!), onDeleted: notifier.limpiarFiltroCuenta),
                if (state.hayRango) ...[
                  const SizedBox(width: 8),
                  InputChip(
                    label: Text('${AppDateUtils.formatDateString(state.desde)} – ${AppDateUtils.formatDateString(state.hasta)}'),
                    onDeleted: notifier.limpiarFiltroFechas,
                  ),
                ],
              ]),
            ),
          if (state.status == MovementListStatus.loaded || state.movimientos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                state.hasFilters
                    ? '${state.total} ${isEn ? 'results' : 'resultados'} · Total ${Money.format(state.filteredTotalCents)}'
                    : (isEn ? 'Last ${state.total} movements' : 'Últimos ${state.total} movimientos'),
                key: const ValueKey('movimientos-resumen'),
                style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(child: _lista(state, isEn)),
        ],
      ),
    );
  }

  Widget _lista(MovementListState state, bool isEn) {
    if (state.isLoading && state.movimientos.isEmpty) return const MovementsSkeleton();
    final error = state.error;
    if (state.status == MovementListStatus.error && state.movimientos.isEmpty && error != null) {
      final code = ErrorMessages.codeOf(error);
      return ListView(children: [
        const SizedBox(height: 60),
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
            onPressed: ref.read(movementListNotifierProvider.notifier).cargarMovimientos,
            child: Text(isEn ? 'Retry' : 'Reintentar'),
          ),
        ),
      ]);
    }
    if (state.movimientos.isEmpty) {
      return Center(child: Text(isEn ? 'No movements' : 'No hay movimientos'));
    }
    return RefreshIndicator(
      onRefresh: ref.read(movementListNotifierProvider.notifier).cargarMovimientos,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: state.movimientos.length + 1,
        itemBuilder: (_, i) {
          if (i == state.movimientos.length) {
            if (state.loadingMore) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(ErrorMessages.describe(error, isEn: isEn),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rose)),
              );
            }
            return const SizedBox(height: 8);
          }
          final item = state.movimientos[i];
          return MovementCard(
            item: item,
            isEn: isEn,
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
