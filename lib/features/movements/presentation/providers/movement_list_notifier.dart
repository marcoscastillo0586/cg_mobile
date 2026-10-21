import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/movement_detail_entity.dart';
import '../../domain/repositories/movement_repository.dart';

import '../../data/repositories/movement_repository_impl.dart';
import 'movement_list_state.dart';

final movementListNotifierProvider =
    StateNotifierProvider.autoDispose<MovementListNotifier, MovementListState>((ref) {
  final repository = ref.watch(movementRepositoryProvider);
  return MovementListNotifier(repository);
});

class MovementListNotifier extends StateNotifier<MovementListState> {
  final MovementRepository _repository;
  int _searchSessionId = 0;

  MovementListNotifier(this._repository) : super(MovementListState.initial());

  Future<void> cargarMovimientos({
    String? desde,
    String? hasta,
    int? idLugar,
    String? nombreLugar,
    int? idCategoria,
  }) async {
    state = state.copyWith(
      status: MovementListStatus.loading,
      desde: desde ?? state.desde,
      hasta: hasta ?? state.hasta,
      idLugar: idLugar ?? state.idLugar,
      nombreLugar: nombreLugar ?? state.nombreLugar,
      idCategoria: idCategoria ?? state.idCategoria,
      errorMessage: null,
    );

    try {
      final res = await _repository.getMovements(
        desde: state.desde,
        hasta: state.hasta,
        idLugar: state.idLugar,
        idCategoria: state.idCategoria,
        limit: 50,
      );

      state = state.copyWith(
        status: MovementListStatus.loaded,
        movimientos: res.movimientos,
        resumen: res.resumen,
      );

      // Si había una búsqueda activa al cambiar de período, re-ejecutarla para el nuevo período
      if (state.busqueda.isNotEmpty) {
        unawaited(setBusqueda(state.busqueda));
      }
    } on Failure catch (e) {
      state = state.copyWith(
        status: MovementListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: MovementListStatus.error,
        errorMessage: 'Error al consultar movimientos: $e',
      );
    }
  }

  Future<void> setBusqueda(String query) async {
    final cleanQ = query.trim();
    state = state.copyWith(busqueda: cleanQ);

    if (cleanQ.isEmpty) {
      state = state.copyWith(
        isSearching: false,
        clearResultadosBusqueda: true,
      );
      return;
    }

    _searchSessionId++;
    final currentSession = _searchSessionId;

    state = state.copyWith(
      isSearching: true,
      clearResultadosBusqueda: true,
      errorMessage: null,
    );

    try {
      final res = await _repository.searchMovements(
        query: cleanQ,
        desde: state.desde,
        hasta: state.hasta,
        idLugar: state.idLugar,
      );

      // Descartar respuestas obsoletas si la búsqueda cambió durante la petición
      if (currentSession != _searchSessionId) return;

      final newCache = Map<int, MovementDetailEntity>.from(state.detallesCache);
      newCache.addAll(res.detallesSearchResult);

      state = state.copyWith(
        isSearching: false,
        resultadosBusqueda: res.movimientos,
        detallesCache: newCache,
      );
    } catch (e) {
      if (currentSession != _searchSessionId) return;
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Error al realizar la búsqueda: $e',
      );
    }
  }

  void limpiarFiltroLugar() {
    state = state.copyWith(idLugar: 0, nombreLugar: null);
    cargarMovimientos(idLugar: 0, nombreLugar: '');
  }

  void limpiarFiltroFechas() {
    state = state.copyWith(desde: null, hasta: null);
    cargarMovimientos(desde: '', hasta: '');
  }

  Future<MovementDetailEntity?> obtenerDetalle(int id) async {
    if (state.detallesCache.containsKey(id)) {
      return state.detallesCache[id];
    }

    try {
      final detail = await _repository.getMovementDetail(id);
      final newCache = Map<int, MovementDetailEntity>.from(state.detallesCache);
      newCache[id] = detail;
      state = state.copyWith(detallesCache: newCache);
      return detail;
    } catch (_) {
      return null;
    }
  }

  Future<bool> actualizarMovimiento(Map<String, dynamic> data) async {
    try {
      final ok = await _repository.updateMovement(data);
      if (ok) {
        await cargarMovimientos();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> eliminarMovimiento(int id) async {
    state = state.copyWith(isDeleting: true);
    try {
      final ok = await _repository.deleteMovement(id);
      if (ok) {
        final actualizados = state.movimientos.where((m) => m.idMovimientoEnc != id).toList();
        state = state.copyWith(movimientos: actualizados, isDeleting: false);
        return true;
      }
    } catch (_) {}
    state = state.copyWith(isDeleting: false);
    return false;
  }
}
