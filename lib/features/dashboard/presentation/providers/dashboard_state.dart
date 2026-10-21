import 'package:equatable/equatable.dart';
import '../../domain/entities/balances.dart';

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final Balances? balances;

  /// Error de la última carga (se traduce en la UI). Con [balances] previos se siguen mostrando.
  final Object? error;
  final String? fechaFiltro;
  final bool ocultarMontos;

  /// null = todas seleccionadas (por defecto).
  final Set<int>? cuentasSeleccionadasIds;

  const DashboardState({
    required this.status,
    this.balances,
    this.error,
    this.fechaFiltro,
    this.ocultarMontos = false,
    this.cuentasSeleccionadasIds,
  });

  factory DashboardState.initial() => const DashboardState(status: DashboardStatus.initial);

  DashboardState copyWith({
    DashboardStatus? status,
    Balances? balances,
    Object? error,
    bool clearError = false,
    String? fechaFiltro,
    bool clearFecha = false,
    bool? ocultarMontos,
    Set<int>? cuentasSeleccionadasIds,
  }) {
    return DashboardState(
      status: status ?? this.status,
      balances: balances ?? this.balances,
      error: clearError ? null : (error ?? this.error),
      fechaFiltro: clearFecha ? null : (fechaFiltro ?? this.fechaFiltro),
      ocultarMontos: ocultarMontos ?? this.ocultarMontos,
      cuentasSeleccionadasIds: cuentasSeleccionadasIds ?? this.cuentasSeleccionadasIds,
    );
  }

  bool get isLoading => status == DashboardStatus.loading;

  Set<int> get idsSeleccionados {
    final b = balances;
    if (b == null) return {};
    return cuentasSeleccionadasIds ?? b.accounts.map((c) => c.id).toSet();
  }

  /// Consolidado en ARS de las cuentas seleccionadas (F1.11), con los saldos ya
  /// convertidos por el servidor. Con todas seleccionadas coincide con totalArsCents.
  int get totalSeleccionadoArsCents {
    final b = balances;
    if (b == null) return 0;
    final ids = idsSeleccionados;
    return b.accounts.where((c) => ids.contains(c.id)).fold(0, (sum, c) => sum + c.balanceArsCents);
  }

  @override
  List<Object?> get props => [status, balances, error, fechaFiltro, ocultarMontos, cuentasSeleccionadasIds];
}
