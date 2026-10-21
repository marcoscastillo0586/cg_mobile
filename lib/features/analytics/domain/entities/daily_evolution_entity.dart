import 'package:equatable/equatable.dart';

class DailyEvolutionItemEntity extends Equatable {
  final int dia;
  final String fecha;
  final double ingresos;
  final double egresos;

  const DailyEvolutionItemEntity({
    required this.dia,
    required this.fecha,
    required this.ingresos,
    required this.egresos,
  });

  @override
  List<Object?> get props => [dia, fecha, ingresos, egresos];
}

class DailyEvolutionReportEntity extends Equatable {
  final int mes;
  final int anio;
  final int diasEnMes;
  final List<DailyEvolutionItemEntity> dias;

  const DailyEvolutionReportEntity({
    required this.mes,
    required this.anio,
    required this.diasEnMes,
    required this.dias,
  });

  double get totalEgresosMes =>
      dias.fold(0.0, (acc, item) => acc + item.egresos);

  double get totalIngresosMes =>
      dias.fold(0.0, (acc, item) => acc + item.ingresos);

  double get maximoGastoDiario =>
      dias.fold(0.0, (max, item) => item.egresos > max ? item.egresos : max);

  @override
  List<Object?> get props => [mes, anio, diasEnMes, dias];
}
