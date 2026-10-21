import '../../domain/entities/account_admin_entity.dart';

class AccountAdminModel extends AccountAdminEntity {
  const AccountAdminModel({
    required super.idLugar,
    required super.nombre,
    required super.img,
    required super.activo,
    required super.tipoMoneda,
    required super.monedaSimbolo,
    required super.esUsd,
    required super.saldoActual,
    required super.cantidadMovimientos,
  });

  factory AccountAdminModel.fromJson(Map<String, dynamic> json) {
    final tipoMoneda = (json['tipo_moneda'] as num?)?.toInt() ?? 1;
    final esUsd = json['es_usd'] as bool? ?? (tipoMoneda == 2);

    return AccountAdminModel(
      idLugar: (json['id_lugar'] as num).toInt(),
      nombre: (json['nombre'] as String? ?? '').trim(),
      img: json['img'] as String? ?? 'assets/img/lugares/default.png',
      activo: json['activo'] as bool? ?? true,
      tipoMoneda: tipoMoneda,
      monedaSimbolo: json['moneda_simbolo'] as String? ?? (esUsd ? 'USD' : 'ARS'),
      esUsd: esUsd,
      saldoActual: (json['saldo_actual'] as num?)?.toDouble() ?? 0.0,
      cantidadMovimientos: (json['cantidad_movimientos'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_lugar': idLugar,
      'nombre': nombre,
      'img': img,
      'activo': activo,
      'tipo_moneda': tipoMoneda,
      'moneda_simbolo': monedaSimbolo,
      'es_usd': esUsd,
      'saldo_actual': saldoActual,
      'cantidad_movimientos': cantidadMovimientos,
    };
  }
}
