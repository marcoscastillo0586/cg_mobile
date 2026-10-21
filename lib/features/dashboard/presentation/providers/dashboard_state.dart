import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_summary_entity.dart';
import '../../domain/entities/expense_limit_entity.dart';

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final DashboardSummaryEntity? summary;
  final List<ExpenseLimitEntity> limites;
  final String? errorMessage;
  final String? fechaFiltro;
  final bool ocultarMontos;
  final Set<int>? cuentasSeleccionadasIds;

  const DashboardState({
    required this.status,
    this.summary,
    this.limites = const [],
    this.errorMessage,
    this.fechaFiltro,
    this.ocultarMontos = false,
    this.cuentasSeleccionadasIds,
  });

  factory DashboardState.initial() => const DashboardState(status: DashboardStatus.initial);

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummaryEntity? summary,
    List<ExpenseLimitEntity>? limites,
    String? errorMessage,
    String? fechaFiltro,
    bool? ocultarMontos,
    Set<int>? cuentasSeleccionadasIds,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      limites: limites ?? this.limites,
      errorMessage: errorMessage ?? this.errorMessage,
      fechaFiltro: fechaFiltro ?? this.fechaFiltro,
      ocultarMontos: ocultarMontos ?? this.ocultarMontos,
      cuentasSeleccionadasIds: cuentasSeleccionadasIds ?? this.cuentasSeleccionadasIds,
    );
  }

  bool get isLoading => status == DashboardStatus.loading;

  /// Obtiene los IDs de las cuentas seleccionadas (por defecto todas)
  Set<int> get idsSeleccionados {
    if (summary == null) return {};
    return cuentasSeleccionadasIds ?? summary!.cuentas.map((c) => c.idLugar).toSet();
  }

  /// Calcula el saldo consolidado general sumando únicamente las cuentas con checkbox marcado
  double get totalPesosConsolidado {
    if (summary == null) return 0.0;
    final seleccionadas = idsSeleccionados;
    double total = 0.0;
    for (final c in summary!.cuentas) {
      if (seleccionadas.contains(c.idLugar)) {
        total += c.montoPesos;
      }
    }
    return total;
  }

  @override
  List<Object?> get props => [
        status,
        summary,
        limites,
        errorMessage,
        fechaFiltro,
        ocultarMontos,
        cuentasSeleccionadasIds,
      ];
}
