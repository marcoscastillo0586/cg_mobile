import '../../domain/entities/monthly_comparison_entity.dart';

class MonthFinancialDataModel extends MonthFinancialDataEntity {
  const MonthFinancialDataModel({
    required super.mes,
    required super.nombreMes,
    required super.ingresos,
    required super.egresos,
    required super.balance,
    required super.tasaAhorro,
  });

  factory MonthFinancialDataModel.fromJson(Map<String, dynamic> json) {
    return MonthFinancialDataModel(
      mes: (json['mes'] as num?)?.toInt() ?? 1,
      nombreMes: json['nombre_mes'] as String? ?? '',
      ingresos: (json['ingresos'] as num?)?.toDouble() ?? 0.0,
      egresos: (json['egresos'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      tasaAhorro: (json['tasa_ahorro'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthExtremeModel extends MonthExtremeEntity {
  const MonthExtremeModel({
    required super.mes,
    required super.nombre,
    required super.monto,
  });

  factory MonthExtremeModel.fromJson(Map<String, dynamic> json) {
    return MonthExtremeModel(
      mes: (json['mes'] as num?)?.toInt() ?? 1,
      nombre: json['nombre'] as String? ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnnualTotalsModel extends AnnualTotalsEntity {
  const AnnualTotalsModel({
    required super.totalIngresos,
    required super.totalEgresos,
    required super.balanceNeto,
    required super.tasaAhorroPorcentaje,
    required super.promedioMensualGasto,
    required super.mesMayorGasto,
    required super.mesMenorGasto,
  });

  factory AnnualTotalsModel.fromJson(Map<String, dynamic> json) {
    return AnnualTotalsModel(
      totalIngresos: (json['total_ingresos'] as num?)?.toDouble() ?? 0.0,
      totalEgresos: (json['total_egresos'] as num?)?.toDouble() ?? 0.0,
      balanceNeto: (json['balance_neto'] as num?)?.toDouble() ?? 0.0,
      tasaAhorroPorcentaje: (json['tasa_ahorro_porcentaje'] as num?)?.toDouble() ?? 0.0,
      promedioMensualGasto: (json['promedio_mensual_gasto'] as num?)?.toDouble() ?? 0.0,
      mesMayorGasto: MonthExtremeModel.fromJson(
        (json['mes_mayor_gasto'] as Map<String, dynamic>?) ?? {},
      ),
      mesMenorGasto: MonthExtremeModel.fromJson(
        (json['mes_menor_gasto'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

class AnnualTopCategoryModel extends AnnualTopCategoryEntity {
  const AnnualTopCategoryModel({
    required super.idCategoria,
    required super.nombre,
    required super.monto,
    required super.porcentaje,
  });

  factory AnnualTopCategoryModel.fromJson(Map<String, dynamic> json) {
    return AnnualTopCategoryModel(
      idCategoria: (json['id_categoria'] as num?)?.toInt() ?? 0,
      nombre: json['nombre'] as String? ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthlyComparisonReportModel extends MonthlyComparisonReportEntity {
  const MonthlyComparisonReportModel({
    required super.anio,
    required super.aniosDisponibles,
    required super.meses,
    required super.totalesAnuales,
    required super.topCategorias,
  });

  factory MonthlyComparisonReportModel.fromJson(Map<String, dynamic> json) {
    final aniosList = (json['anios_disponibles'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];

    final mesesList = (json['meses'] as List<dynamic>?)
            ?.map((e) => MonthFinancialDataModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final topCatList = (json['top_categorias_anual'] as List<dynamic>?)
            ?.map((e) => AnnualTopCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MonthlyComparisonReportModel(
      anio: (json['anio'] as num?)?.toInt() ?? DateTime.now().year,
      aniosDisponibles: aniosList,
      meses: mesesList,
      totalesAnuales: AnnualTotalsModel.fromJson(
        (json['totales_anuales'] as Map<String, dynamic>?) ?? {},
      ),
      topCategorias: topCatList,
    );
  }
}
