import 'package:equatable/equatable.dart';

class ExpenseLimitAdminEntity extends Equatable {
  final int idLimiteGasto;
  final DateTime desde;
  final DateTime hasta;
  final double montoLimite;
  final double montoConsumido;
  final double resto;
  final double porcentaje;
  final bool vencido;
  final String categoria;
  final String categoriasNombres;
  final String lugar;
  final String lugaresNombres;
  final String? syncId;

  const ExpenseLimitAdminEntity({
    required this.idLimiteGasto,
    required this.desde,
    required this.hasta,
    required this.montoLimite,
    this.montoConsumido = 0.0,
    this.resto = 0.0,
    this.porcentaje = 0.0,
    this.vencido = false,
    this.categoria = '',
    this.categoriasNombres = '',
    this.lugar = '',
    this.lugaresNombres = '',
    this.syncId,
  });

  bool get excedido => resto < 0;

  double get factorUso => (montoLimite > 0 ? (montoConsumido / montoLimite) : 0.0).clamp(0.0, 1.0);

  int get diasRestantes {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limitEnd = DateTime(hasta.year, hasta.month, hasta.day);
    return limitEnd.difference(today).inDays;
  }

  List<int> get categoriasIds {
    if (categoria.trim().isEmpty) return [];
    return categoria
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  List<int> get lugaresIds {
    if (lugar.trim().isEmpty) return [];
    return lugar
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  @override
  List<Object?> get props => [
        idLimiteGasto,
        desde,
        hasta,
        montoLimite,
        montoConsumido,
        resto,
        porcentaje,
        vencido,
        categoria,
        categoriasNombres,
        lugar,
        lugaresNombres,
        syncId,
      ];
}
