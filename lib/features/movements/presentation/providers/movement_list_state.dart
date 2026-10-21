import 'package:equatable/equatable.dart';
import '../../domain/entities/movement_detail_entity.dart';
import '../../domain/entities/movement_entity.dart';

enum MovementListStatus { initial, loading, loaded, error }

class MovementListState extends Equatable {
  final MovementListStatus status;
  final List<MovementEntity> movimientos;
  final Map<int, MovementDetailEntity> detallesCache;
  final MovementsSummaryEntity? resumen;
  final String? desde;
  final String? hasta;
  final int? idLugar;
  final String? nombreLugar;
  final int? idCategoria;
  final String busqueda;
  final bool isSearching;
  final List<MovementEntity>? resultadosBusqueda;
  final String? errorMessage;
  final bool isDeleting;

  const MovementListState({
    required this.status,
    this.movimientos = const [],
    this.detallesCache = const {},
    this.resumen,
    this.desde,
    this.hasta,
    this.idLugar,
    this.nombreLugar,
    this.idCategoria,
    this.busqueda = '',
    this.isSearching = false,
    this.resultadosBusqueda,
    this.errorMessage,
    this.isDeleting = false,
  });

  factory MovementListState.initial() => const MovementListState(
        status: MovementListStatus.initial,
      );

  MovementListState copyWith({
    MovementListStatus? status,
    List<MovementEntity>? movimientos,
    Map<int, MovementDetailEntity>? detallesCache,
    MovementsSummaryEntity? resumen,
    String? desde,
    String? hasta,
    int? idLugar,
    String? nombreLugar,
    int? idCategoria,
    String? busqueda,
    bool? isSearching,
    List<MovementEntity>? resultadosBusqueda,
    bool clearResultadosBusqueda = false,
    String? errorMessage,
    bool? isDeleting,
  }) {
    return MovementListState(
      status: status ?? this.status,
      movimientos: movimientos ?? this.movimientos,
      detallesCache: detallesCache ?? this.detallesCache,
      resumen: resumen ?? this.resumen,
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      idLugar: idLugar ?? this.idLugar,
      nombreLugar: nombreLugar ?? this.nombreLugar,
      idCategoria: idCategoria ?? this.idCategoria,
      busqueda: busqueda ?? this.busqueda,
      isSearching: isSearching ?? this.isSearching,
      resultadosBusqueda: clearResultadosBusqueda
          ? null
          : (resultadosBusqueda ?? this.resultadosBusqueda),
      errorMessage: errorMessage ?? this.errorMessage,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  bool get isLoading => status == MovementListStatus.loading;
  bool get hasFilters =>
      (idLugar != null && idLugar! > 0) ||
      (desde != null && desde!.isNotEmpty) ||
      (hasta != null && hasta!.isNotEmpty) ||
      busqueda.trim().isNotEmpty;

  List<MovementEntity> get movimientosFiltrados =>
      busqueda.trim().isNotEmpty ? (resultadosBusqueda ?? []) : movimientos;

  @override
  List<Object?> get props => [
        status,
        movimientos,
        detallesCache,
        resumen,
        desde,
        hasta,
        idLugar,
        nombreLugar,
        idCategoria,
        busqueda,
        isSearching,
        resultadosBusqueda,
        errorMessage,
        isDeleting,
      ];
}
