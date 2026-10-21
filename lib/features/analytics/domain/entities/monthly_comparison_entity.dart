import 'package:equatable/equatable.dart';

class MonthFinancialDataEntity extends Equatable {
  final int mes;
  final String nombreMes;
  final double ingresos;
  final double egresos;
  final double balance;
  final double tasaAhorro;

  const MonthFinancialDataEntity({
    required this.mes,
    required this.nombreMes,
    required this.ingresos,
    required this.egresos,
    required this.balance,
    required this.tasaAhorro,
  });

  bool get esSuperavit => balance >= 0;

  @override
  List<Object?> get props => [mes, nombreMes, ingresos, egresos, balance, tasaAhorro];
}

class MonthExtremeEntity extends Equatable {
  final int mes;
  final String nombre;
  final double monto;

  const MonthExtremeEntity({
    required this.mes,
    required this.nombre,
    required this.monto,
  });

  @override
  List<Object?> get props => [mes, nombre, monto];
}

class AnnualTotalsEntity extends Equatable {
  final double totalIngresos;
  final double totalEgresos;
  final double balanceNeto;
  final double tasaAhorroPorcentaje;
  final double promedioMensualGasto;
  final MonthExtremeEntity mesMayorGasto;
  final MonthExtremeEntity mesMenorGasto;

  const AnnualTotalsEntity({
    required this.totalIngresos,
    required this.totalEgresos,
    required this.balanceNeto,
    required this.tasaAhorroPorcentaje,
    required this.promedioMensualGasto,
    required this.mesMayorGasto,
    required this.mesMenorGasto,
  });

  @override
  List<Object?> get props => [
        totalIngresos,
        totalEgresos,
        balanceNeto,
        tasaAhorroPorcentaje,
        promedioMensualGasto,
        mesMayorGasto,
        mesMenorGasto,
      ];
}

class AnnualTopCategoryEntity extends Equatable {
  final int idCategoria;
  final String nombre;
  final double monto;
  final double porcentaje;

  const AnnualTopCategoryEntity({
    required this.idCategoria,
    required this.nombre,
    required this.monto,
    required this.porcentaje,
  });

  @override
  List<Object?> get props => [idCategoria, nombre, monto, porcentaje];
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
