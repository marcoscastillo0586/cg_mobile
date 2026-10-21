import 'package:equatable/equatable.dart';
import 'account_entity.dart';

class DashboardSummaryEntity extends Equatable {
  final double sumaTotalPesos;
  final String cotizacionNombre;
  final double cotizacionDolar;
  final String? fechaFiltro;
  final List<AccountEntity> cuentas;

  const DashboardSummaryEntity({
    required this.sumaTotalPesos,
    required this.cotizacionNombre,
    required this.cotizacionDolar,
    this.fechaFiltro,
    required this.cuentas,
  });

  @override
  List<Object?> get props => [
        sumaTotalPesos,
        cotizacionNombre,
        cotizacionDolar,
        fechaFiltro,
        cuentas,
      ];
}
