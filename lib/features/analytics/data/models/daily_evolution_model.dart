import '../../domain/entities/daily_evolution_entity.dart';

class DailyEvolutionItemModel extends DailyEvolutionItemEntity {
  const DailyEvolutionItemModel({
    required super.dia,
    required super.fecha,
    required super.ingresos,
    required super.egresos,
  });

  factory DailyEvolutionItemModel.fromJson(Map<String, dynamic> json) {
    return DailyEvolutionItemModel(
      dia: (json['dia'] as num?)?.toInt() ?? 1,
      fecha: json['fecha'] as String? ?? '',
      ingresos: (json['ingresos'] as num?)?.toDouble() ?? 0.0,
      egresos: (json['egresos'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyEvolutionReportModel extends DailyEvolutionReportEntity {
  const DailyEvolutionReportModel({
    required super.mes,
    required super.anio,
    required super.diasEnMes,
    required super.dias,
  });

  factory DailyEvolutionReportModel.fromJson(Map<String, dynamic> json) {
    final diasList = (json['dias'] as List<dynamic>?)
            ?.map((e) => DailyEvolutionItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return DailyEvolutionReportModel(
      mes: (json['mes'] as num?)?.toInt() ?? DateTime.now().month,
      anio: (json['anio'] as num?)?.toInt() ?? DateTime.now().year,
      diasEnMes: (json['dias_en_mes'] as num?)?.toInt() ?? 30,
      dias: diasList,
    );
  }
}
