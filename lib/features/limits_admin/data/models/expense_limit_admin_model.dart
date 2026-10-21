import '../../domain/entities/expense_limit_admin_entity.dart';

class ExpenseLimitAdminModel extends ExpenseLimitAdminEntity {
  const ExpenseLimitAdminModel({
    required super.idLimiteGasto,
    required super.desde,
    required super.hasta,
    required super.montoLimite,
    required super.montoConsumido,
    required super.resto,
    required super.porcentaje,
    required super.vencido,
    required super.categoria,
    required super.categoriasNombres,
    required super.lugar,
    required super.lugaresNombres,
  });

  factory ExpenseLimitAdminModel.fromJson(Map<String, dynamic> json) {
    final desdeRaw = json['desde']?.toString() ?? '';
    final hastaRaw = json['hasta']?.toString() ?? '';

    return ExpenseLimitAdminModel(
      idLimiteGasto: json['id_limite_gasto'] is int
          ? json['id_limite_gasto'] as int
          : int.tryParse(json['id_limite_gasto']?.toString() ?? '0') ?? 0,
      desde: DateTime.tryParse(desdeRaw) ?? DateTime.now(),
      hasta: DateTime.tryParse(hastaRaw) ?? DateTime.now(),
      montoLimite: (json['monto_limite'] as num?)?.toDouble() ?? 0.0,
      montoConsumido: (json['monto_consumido'] as num?)?.toDouble() ?? 0.0,
      resto: (json['resto'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      vencido: json['vencido'] as bool? ?? false,
      categoria: json['categoria']?.toString() ?? '',
      categoriasNombres: json['categorias_nombres']?.toString() ?? 'General',
      lugar: json['lugar']?.toString() ?? '',
      lugaresNombres: json['lugares_nombres']?.toString() ?? 'Todas las cuentas',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_limite_gasto': idLimiteGasto,
      'desde': "${desde.year.toString().padLeft(4, '0')}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}",
      'hasta': "${hasta.year.toString().padLeft(4, '0')}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}",
      'monto_limite': montoLimite,
      'monto_consumido': montoConsumido,
      'resto': resto,
      'porcentaje': porcentaje,
      'vencido': vencido,
      'categoria': categoria,
      'categorias_nombres': categoriasNombres,
      'lugar': lugar,
      'lugares_nombres': lugaresNombres,
    };
  }
}
