import 'package:equatable/equatable.dart';

class AccountAdminEntity extends Equatable {
  final int idLugar;
  final String nombre;
  final String img;
  final bool activo;
  final int tipoMoneda;
  final String monedaSimbolo;
  final bool esUsd;
  final double saldoActual;
  final int cantidadMovimientos;
  final String? syncId;

  const AccountAdminEntity({
    required this.idLugar,
    required this.nombre,
    this.img = '',
    required this.activo,
    required this.tipoMoneda,
    this.monedaSimbolo = '\$',
    this.esUsd = false,
    this.saldoActual = 0.0,
    this.cantidadMovimientos = 0,
    this.syncId,
  });

  AccountAdminEntity copyWith({
    int? idLugar,
    String? nombre,
    String? img,
    bool? activo,
    int? tipoMoneda,
    String? monedaSimbolo,
    bool? esUsd,
    double? saldoActual,
    int? cantidadMovimientos,
    String? syncId,
  }) {
    return AccountAdminEntity(
      idLugar: idLugar ?? this.idLugar,
      nombre: nombre ?? this.nombre,
      img: img ?? this.img,
      activo: activo ?? this.activo,
      tipoMoneda: tipoMoneda ?? this.tipoMoneda,
      monedaSimbolo: monedaSimbolo ?? this.monedaSimbolo,
      esUsd: esUsd ?? this.esUsd,
      saldoActual: saldoActual ?? this.saldoActual,
      cantidadMovimientos: cantidadMovimientos ?? this.cantidadMovimientos,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  List<Object?> get props => [
        idLugar,
        nombre,
        img,
        activo,
        tipoMoneda,
        monedaSimbolo,
        esUsd,
        saldoActual,
        cantidadMovimientos,
        syncId,
      ];
}
