import 'package:equatable/equatable.dart';

/// Día del mes (GET /reports/daily). Importes en centavos.
class DailyEvolutionItemEntity extends Equatable {
  final int dia;

  /// `yyyy-MM-dd`.
  final String fecha;
  final int ingresosCents;
  final int egresosCents;

  const DailyEvolutionItemEntity({required this.dia, required this.fecha, required this.ingresosCents, required this.egresosCents});

  @override
  List<Object?> get props => [dia, fecha, ingresosCents, egresosCents];
}

class DailyEvolutionReportEntity extends Equatable {
  final int mes;
  final int anio;
  final List<DailyEvolutionItemEntity> dias;

  const DailyEvolutionReportEntity({required this.mes, required this.anio, required this.dias});

  int get diasEnMes => dias.length;
  int get totalEgresosMesCents => dias.fold(0, (a, d) => a + d.egresosCents);
  int get totalIngresosMesCents => dias.fold(0, (a, d) => a + d.ingresosCents);
  int get maximoGastoDiarioCents => dias.fold(0, (a, d) => d.egresosCents > a ? d.egresosCents : a);

  @override
  List<Object?> get props => [mes, anio, dias];
}
