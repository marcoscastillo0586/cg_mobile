import 'package:equatable/equatable.dart';

const _mesesEs = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

String nombreMes(int mes) => (mes >= 1 && mes <= 12) ? _mesesEs[mes - 1] : '$mes';

/// Mes de la comparativa ingresos / egresos / ahorro (GET /reports/income-expense).
class MonthFinancialDataEntity extends Equatable {
  final int mes;
  final int ingresosCents;
  final int egresosCents;
  final int balanceCents;

  /// Tasa de ahorro en % (la calcula el servidor).
  final num tasaAhorro;

  const MonthFinancialDataEntity({
    required this.mes,
    required this.ingresosCents,
    required this.egresosCents,
    required this.balanceCents,
    required this.tasaAhorro,
  });

  String get nombreMesTexto => nombreMes(mes);
  bool get esSuperavit => balanceCents >= 0;

  @override
  List<Object?> get props => [mes, ingresosCents, egresosCents, balanceCents, tasaAhorro];
}

class MonthExtremeEntity extends Equatable {
  final int mes;
  final int montoCents;
  const MonthExtremeEntity({required this.mes, required this.montoCents});

  String get nombre => nombreMes(mes);

  @override
  List<Object?> get props => [mes, montoCents];
}

class AnnualTotalsEntity extends Equatable {
  final int totalIngresosCents;
  final int totalEgresosCents;
  final int balanceNetoCents;
  final num tasaAhorroPorcentaje;
  final int promedioMensualGastoCents;
  final MonthExtremeEntity? mesMayorGasto;
  final MonthExtremeEntity? mesMenorGasto;

  const AnnualTotalsEntity({
    required this.totalIngresosCents,
    required this.totalEgresosCents,
    required this.balanceNetoCents,
    required this.tasaAhorroPorcentaje,
    required this.promedioMensualGastoCents,
    required this.mesMayorGasto,
    required this.mesMenorGasto,
  });

  @override
  List<Object?> get props => [
        totalIngresosCents,
        totalEgresosCents,
        balanceNetoCents,
        tasaAhorroPorcentaje,
        promedioMensualGastoCents,
        mesMayorGasto,
        mesMenorGasto,
      ];
}

class AnnualTopCategoryEntity extends Equatable {
  final int idCategoria;
  final String nombre;
  final int montoCents;
  final num porcentaje;

  const AnnualTopCategoryEntity({required this.idCategoria, required this.nombre, required this.montoCents, required this.porcentaje});

  @override
  List<Object?> get props => [idCategoria, nombre, montoCents, porcentaje];
}

class MonthlyComparisonReportEntity extends Equatable {
  final int anio;
  final List<int> aniosDisponibles;
  final List<MonthFinancialDataEntity> meses;
  final AnnualTotalsEntity totalesAnuales;
  final List<AnnualTopCategoryEntity> topCategorias;

  const MonthlyComparisonReportEntity({
    required this.anio,
    required this.aniosDisponibles,
    required this.meses,
    required this.totalesAnuales,
    required this.topCategorias,
  });

  @override
  List<Object?> get props => [anio, aniosDisponibles, meses, totalesAnuales, topCategorias];
}
