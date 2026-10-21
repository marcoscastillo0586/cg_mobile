import 'package:equatable/equatable.dart';

class ExpenseLimitEntity extends Equatable {
  final int idLimiteGasto;
  final String nombre;
  final String categorias;
  final String lugares;
  final double montoLimite;
  final double montoConsumido;
  final double resto;
  final double porcentaje;
  final bool vencido;

  const ExpenseLimitEntity({
    required this.idLimiteGasto,
    required this.nombre,
    required this.categorias,
    required this.lugares,
    required this.montoLimite,
    required this.montoConsumido,
    required this.resto,
    required this.porcentaje,
    required this.vencido,
  });

  bool get excedido => resto < 0;

  @override
  List<Object?> get props => [
        idLimiteGasto,
        nombre,
        categorias,
        lugares,
        montoLimite,
        montoConsumido,
        resto,
        porcentaje,
        vencido,
      ];
}
