import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/balances.dart';

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final Balances? balances;

  /// Error de la última carga (se traduce en la UI). Con [balances] previos se siguen mostrando.
  final Object? error;
  final String? fechaFiltro;
  final bool ocultarMontos;

  /// Cuentas que el usuario desmarcó. Las demás (incluidas las que aparecen después, p. ej. al
  /// terminar la primera descarga) suman en el consolidado.
  final Set<int> cuentasExcluidasIds;

  const DashboardState({
    required this.status,
    this.balances,
    this.error,
    this.fechaFiltro,
    this.ocultarMontos = false,
    this.cuentasExcluidasIds = const {},
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
    Set<int>? cuentasExcluidasIds,
  }) {
    return DashboardState(
      status: status ?? this.status,
      balances: balances ?? this.balances,
      error: clearError ? null : (error ?? this.error),
      fechaFiltro: clearFecha ? null : (fechaFiltro ?? this.fechaFiltro),
      ocultarMontos: ocultarMontos ?? this.ocultarMontos,
      cuentasExcluidasIds: cuentasExcluidasIds ?? this.cuentasExcluidasIds,
    );
  }

  bool get isLoading => status == DashboardStatus.loading;

  Set<int> get idsSeleccionados {
    final b = balances;
    if (b == null) return {};
    return b.accounts.map((c) => c.id).where((id) => !cuentasExcluidasIds.contains(id)).toSet();
  }

  /// Total de las cuentas seleccionadas de esa moneda (F1.11). Sin conversión entre monedas.
  int totalSeleccionadoCents(Currency moneda) {
    final b = balances;
    if (b == null) return 0;
    final ids = idsSeleccionados;
    return b.accounts.where((c) => c.currency == moneda && ids.contains(c.id)).fold(0, (sum, c) => sum + c.balanceCents);
  }

  @override
  List<Object?> get props => [status, balances, error, fechaFiltro, ocultarMontos, cuentasExcluidasIds];
}
