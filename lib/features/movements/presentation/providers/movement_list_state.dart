import 'package:equatable/equatable.dart';
import '../../domain/movement_item.dart';

enum MovementListStatus { initial, loading, loaded, error }

class MovementListState extends Equatable {
  final MovementListStatus status;
  final List<MovementItem> movimientos;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final int filteredTotalCents;
  final String? desde;
  final String? hasta;
  final int? idCuenta;
  final String? nombreCuenta;
  final String busqueda;
  final Object? error;

  const MovementListState({
    required this.status,
    this.movimientos = const [],
    this.total = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.filteredTotalCents = 0,
    this.desde,
    this.hasta,
    this.idCuenta,
    this.nombreCuenta,
    this.busqueda = '',
    this.error,
  });

  factory MovementListState.initial() => const MovementListState(status: MovementListStatus.initial);

  bool get isLoading => status == MovementListStatus.loading;
  bool get hayRango => (desde ?? '').isNotEmpty || (hasta ?? '').isNotEmpty;
  bool get hasFilters => idCuenta != null || hayRango || busqueda.isNotEmpty;

  MovementListState copyWith({
    MovementListStatus? status,
    List<MovementItem>? movimientos,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    int? filteredTotalCents,
    String? desde,
    String? hasta,
    bool clearRango = false,
    int? idCuenta,
    String? nombreCuenta,
    bool clearCuenta = false,
    String? busqueda,
    Object? error,
    bool clearError = false,
  }) {
    return MovementListState(
      status: status ?? this.status,
      movimientos: movimientos ?? this.movimientos,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      filteredTotalCents: filteredTotalCents ?? this.filteredTotalCents,
      desde: clearRango ? null : (desde ?? this.desde),
      hasta: clearRango ? null : (hasta ?? this.hasta),
      idCuenta: clearCuenta ? null : (idCuenta ?? this.idCuenta),
      nombreCuenta: clearCuenta ? null : (nombreCuenta ?? this.nombreCuenta),
      busqueda: busqueda ?? this.busqueda,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [status, movimientos, total, hasMore, loadingMore, filteredTotalCents, desde, hasta, idCuenta, nombreCuenta, busqueda, error];
}
