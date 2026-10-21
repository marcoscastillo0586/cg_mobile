import '../../domain/entities/expense_limit_entity.dart';

class ExpenseLimitModel extends ExpenseLimitEntity {
  const ExpenseLimitModel({
    required super.idLimiteGasto,
    required super.nombre,
    required super.categorias,
    required super.lugares,
    required super.montoLimite,
    required super.montoConsumido,
    required super.resto,
    required super.porcentaje,
    required super.vencido,
  });

  factory ExpenseLimitModel.fromJson(Map<String, dynamic> json) {
    return ExpenseLimitModel(
      idLimiteGasto: json['id_limite_gasto'] is int
          ? json['id_limite_gasto'] as int
          : int.tryParse(json['id_limite_gasto']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? 'Límite',
      categorias: json['categorias'] as String? ?? '',
      lugares: json['lugares'] as String? ?? '',
      montoLimite: (json['monto_limite'] as num?)?.toDouble() ?? 0.0,
      montoConsumido: (json['monto_consumido'] as num?)?.toDouble() ?? 0.0,
      resto: (json['resto'] as num?)?.toDouble() ?? 0.0,
      porcentaje: (json['porcentaje'] as num?)?.toDouble() ?? 0.0,
      vencido: json['vencido'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_limite_gasto': idLimiteGasto,
      'nombre': nombre,
      'categorias': categorias,
      'lugares': lugares,
      'monto_limite': montoLimite,
      'monto_consumido': montoConsumido,
      'resto': resto,
      'porcentaje': porcentaje,
      'vencido': vencido,
    };
  }
}
