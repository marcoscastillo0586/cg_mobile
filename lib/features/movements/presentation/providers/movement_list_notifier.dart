import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/movements_repository.dart';
import 'movement_list_state.dart';

final movementListNotifierProvider =
    StateNotifierProvider.autoDispose<MovementListNotifier, MovementListState>((ref) {
  return MovementListNotifier(ref.watch(movementsRepositoryProvider));
});

/// Historial (GET /movements) con filtros, búsqueda y paginación. Solo lectura.
class MovementListNotifier extends StateNotifier<MovementListState> {
  final MovementsRepository _repository;
  static const pageSize = 50;

  /// Descarta respuestas de consultas viejas (p. ej. si cambió la búsqueda mientras tanto).
  int _requestId = 0;

  MovementListNotifier(this._repository) : super(MovementListState.initial());

  MovementsQuery _query(int offset) => MovementsQuery(
        from: state.desde,
        to: state.hasta,
        accountIds: state.idCuenta == null ? const [] : [state.idCuenta!],
        q: state.busqueda,
        limit: pageSize,
        offset: offset,
      );

  /// [silencioso]: recarga tras una sincronización que trajo cambios, sin mostrar "cargando".
  Future<void> cargarMovimientos({bool silencioso = false}) async {
    final id = ++_requestId;
    if (!silencioso) state = state.copyWith(status: MovementListStatus.loading, clearError: true);
    try {
      final page = await _repository.getMovements(_query(0));
      if (!mounted || id != _requestId) return;
      state = state.copyWith(
        status: MovementListStatus.loaded,
        movimientos: page.items,
        total: page.total,
        hasMore: page.hasMore,
        filteredTotalCents: page.filteredTotalCents,
      );
    } catch (e) {
      debugPrint('[MOVIMIENTOS] No se pudieron cargar: $e');
      if (!mounted || id != _requestId) return;
      state = state.copyWith(status: MovementListStatus.error, error: e);
    }
  }

  Future<void> cargarMas() async {
    if (!state.hasMore || state.loadingMore || state.isLoading) return;
    final id = _requestId;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _repository.getMovements(_query(state.movimientos.length));
      if (!mounted || id != _requestId) return;
      state = state.copyWith(
        loadingMore: false,
        movimientos: [...state.movimientos, ...page.items],
        total: page.total,
        hasMore: page.hasMore,
      );
    } catch (e) {
      debugPrint('[MOVIMIENTOS] No se pudo cargar la página siguiente: $e');
      if (!mounted || id != _requestId) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  Future<void> inicializar({int? idCuenta, String? nombreCuenta}) {
    if (idCuenta != null) state = state.copyWith(idCuenta: idCuenta, nombreCuenta: nombreCuenta);
    return cargarMovimientos();
  }

  Future<void> setBusqueda(String query) {
    state = state.copyWith(busqueda: query.trim());
    return cargarMovimientos();
  }

  Future<void> setRango(String desde, String hasta) {
    state = state.copyWith(desde: desde, hasta: hasta);
    return cargarMovimientos();
  }

  Future<void> limpiarFiltroFechas() {
    state = state.copyWith(clearRango: true);
    return cargarMovimientos();
  }

  Future<void> limpiarFiltroCuenta() {
    state = state.copyWith(clearCuenta: true);
    return cargarMovimientos();
  }
}
