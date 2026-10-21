import '../../domain/entities/account_entity.dart';

class AccountModel extends AccountEntity {
  const AccountModel({
    required super.idLugar,
    required super.nombre,
    required super.tipoMoneda,
    required super.simboloMoneda,
    required super.montoOriginal,
    required super.montoPesos,
    required super.cotizacion,
    super.imgUrl,
    super.imgBase64,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      idLugar: json['id_lugar'] is int
          ? json['id_lugar'] as int
          : int.tryParse(json['id_lugar']?.toString() ?? '0') ?? 0,
      nombre: json['nombre'] as String? ?? '',
      tipoMoneda: json['tipo_moneda'] is int
          ? json['tipo_moneda'] as int
          : int.tryParse(json['tipo_moneda']?.toString() ?? '1') ?? 1,
      simboloMoneda: json['simbolo_moneda'] as String? ?? 'ARS',
      montoOriginal: (json['monto_original'] as num?)?.toDouble() ?? 0.0,
      montoPesos: (json['monto_pesos'] as num?)?.toDouble() ?? 0.0,
      cotizacion: (json['cotizacion'] as num?)?.toDouble() ?? 1.0,
      imgUrl: json['img_url'] as String?,
      imgBase64: json['img_base64'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_lugar': idLugar,
      'nombre': nombre,
      'tipo_moneda': tipoMoneda,
      'simbolo_moneda': simboloMoneda,
      'monto_original': montoOriginal,
      'monto_pesos': montoPesos,
      'cotizacion': cotizacion,
      'img_url': imgUrl,
      'img_base64': imgBase64,
    };
  }
}
