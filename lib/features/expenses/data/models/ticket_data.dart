import 'package:equatable/equatable.dart';

class ComercioData extends Equatable {
  final String? nombreComercial;
  final String? razonSocial;
  final String? cuit;
  final bool? cuitValido;
  final String? cuitMotivo;
  final String? domicilio;
  final String? localidad;
  final String? provincia;
  final String? condicionIvaEmisor;
  final String? ingresosBrutos;
  final String? inicioActividades;
  final String? tipoComprobante;
  final String? puntoDeVenta;
  final String? numeroComprobante;
  final String? fecha;
  final String? hora;

  const ComercioData({
    this.nombreComercial,
    this.razonSocial,
    this.cuit,
    this.cuitValido,
    this.cuitMotivo,
    this.domicilio,
    this.localidad,
    this.provincia,
    this.condicionIvaEmisor,
    this.ingresosBrutos,
    this.inicioActividades,
    this.tipoComprobante,
    this.puntoDeVenta,
    this.numeroComprobante,
    this.fecha,
    this.hora,
  });

  factory ComercioData.fromJson(Map<String, dynamic> json) {
    return ComercioData(
      nombreComercial: json['nombre_comercial']?.toString().trim(),
      razonSocial: json['razon_social']?.toString().trim(),
      cuit: json['cuit']?.toString().trim(),
      cuitValido: json['cuit_valido'] as bool?,
      cuitMotivo: json['cuit_motivo']?.toString().trim(),
      domicilio: json['domicilio']?.toString().trim(),
      localidad: json['localidad']?.toString().trim(),
      provincia: json['provincia']?.toString().trim(),
      condicionIvaEmisor: json['condicion_iva_emisor']?.toString().trim(),
      ingresosBrutos: json['ingresos_brutos']?.toString().trim(),
      inicioActividades: json['inicio_actividades']?.toString().trim(),
      tipoComprobante: json['tipo_comprobante']?.toString().trim(),
      puntoDeVenta: json['punto_de_venta']?.toString().trim(),
      numeroComprobante: json['numero_comprobante']?.toString().trim(),
      fecha: json['fecha']?.toString().trim(),
      hora: json['hora']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_comercial': nombreComercial,
      'razon_social': razonSocial,
      'cuit': cuit,
      'cuit_valido': cuitValido,
      'cuit_motivo': cuitMotivo,
      'domicilio': domicilio,
      'localidad': localidad,
      'provincia': provincia,
      'condicion_iva_emisor': condicionIvaEmisor,
      'ingresos_brutos': ingresosBrutos,
      'inicio_actividades': inicioActividades,
      'tipo_comprobante': tipoComprobante,
      'punto_de_venta': puntoDeVenta,
      'numero_comprobante': numeroComprobante,
      'fecha': fecha,
      'hora': hora,
    };
  }

  bool get tieneCamposDudosos => cuitValido == false;

  @override
  List<Object?> get props => [
        nombreComercial,
        razonSocial,
        cuit,
        cuitValido,
        cuitMotivo,
        domicilio,
        localidad,
        provincia,
        condicionIvaEmisor,
        ingresosBrutos,
        inicioActividades,
        tipoComprobante,
        puntoDeVenta,
        numeroComprobante,
        fecha,
        hora,
      ];
}

class TicketItemData extends Equatable {
  final String descripcion;
  final double cantidad;
  final double? precioUnitario;
  final double descuento;
  final double subtotal;

  const TicketItemData({
    required this.descripcion,
    required this.cantidad,
    this.precioUnitario,
    required this.descuento,
    required this.subtotal,
  });

  factory TicketItemData.fromJson(Map<String, dynamic> json) {
    final desc = json['descripcion']?.toString().trim() ?? json['nombre']?.toString().trim() ?? '';
    final cant = (json['cantidad'] as num?)?.toDouble() ?? 1.0;
    final pUnit = (json['precio_unitario'] as num?)?.toDouble() ?? (json['precio_bruto'] as num?)?.toDouble();
    final descVal = (json['descuento'] as num?)?.toDouble() ?? 0.0;
    
    double subVal;
    if (json['precio_final'] != null && json['precio_final'] is num) {
      subVal = (json['precio_final'] as num).toDouble();
    } else if (json['subtotal'] != null && json['subtotal'] is num) {
      subVal = (json['subtotal'] as num).toDouble();
    } else if (pUnit != null) {
      subVal = (cant * pUnit) - descVal;
    } else {
      subVal = 0.0;
    }

    return TicketItemData(
      descripcion: desc,
      cantidad: cant > 0 ? cant : 1.0,
      precioUnitario: pUnit,
      descuento: descVal >= 0 ? descVal : 0.0,
      subtotal: subVal >= 0 ? subVal : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'descuento': descuento,
      'subtotal': subtotal,
    };
  }

  @override
  List<Object?> get props => [
        descripcion,
        cantidad,
        precioUnitario,
        descuento,
        subtotal,
      ];
}

class TicketData extends Equatable {
  final ComercioData? comercio;
  final String? fecha;
  final String? moneda;
  final List<TicketItemData> items;
  final double descuentoGeneral;
  final double? total;

  const TicketData({
    this.comercio,
    this.fecha,
    this.moneda,
    this.items = const [],
    this.descuentoGeneral = 0.0,
    this.total,
  });

  factory TicketData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .whereType<Map<String, dynamic>>()
        .map((e) => TicketItemData.fromJson(e))
        .toList();

    ComercioData? com;
    if (json['comercio'] != null && json['comercio'] is Map<String, dynamic>) {
      com = ComercioData.fromJson(json['comercio'] as Map<String, dynamic>);
    }

    return TicketData(
      comercio: com,
      fecha: json['fecha']?.toString().trim() ?? com?.fecha,
      moneda: json['moneda']?.toString().trim(),
      items: itemsList,
      descuentoGeneral: (json['descuento_general'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? (json['total_detectado'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comercio': comercio?.toJson(),
      'fecha': fecha,
      'moneda': moneda,
      'items': items.map((i) => i.toJson()).toList(),
      'descuento_general': descuentoGeneral,
      'total': total,
    };
  }

  @override
  List<Object?> get props => [
        comercio,
        fecha,
        moneda,
        items,
        descuentoGeneral,
        total,
      ];
}
