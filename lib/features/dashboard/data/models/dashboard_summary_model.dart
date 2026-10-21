import '../../domain/entities/dashboard_summary_entity.dart';
import 'account_model.dart';

class DashboardSummaryModel extends DashboardSummaryEntity {
  const DashboardSummaryModel({
    required super.sumaTotalPesos,
    required super.cotizacionNombre,
    required super.cotizacionDolar,
    super.fechaFiltro,
    required super.cuentas,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final cotizacionMap = json['cotizacion_dolar'] as Map<String, dynamic>? ?? {};
    final rawCuentas = json['cuentas'] as List<dynamic>? ?? [];

    final cuentasParsed = rawCuentas
        .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DashboardSummaryModel(
      sumaTotalPesos: (json['suma_total_pesos'] as num?)?.toDouble() ?? 0.0,
      cotizacionNombre: cotizacionMap['nombre'] as String? ?? 'Dólar Blue',
      cotizacionDolar: (cotizacionMap['cotizacion'] as num?)?.toDouble() ?? 1250.0,
      fechaFiltro: json['fecha_filtro'] as String?,
      cuentas: cuentasParsed,
    );
  }
}
