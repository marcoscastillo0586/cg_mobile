import 'package:equatable/equatable.dart';

class ExpenseItemEntity extends Equatable {
  final double monto;
  final int idCategoria;
  final String concepto;

  const ExpenseItemEntity({
    required this.monto,
    required this.idCategoria,
    required this.concepto,
  });

  ExpenseItemEntity copyWith({
    double? monto,
    int? idCategoria,
    String? concepto,
  }) {
    return ExpenseItemEntity(
      monto: monto ?? this.monto,
      idCategoria: idCategoria ?? this.idCategoria,
      concepto: concepto ?? this.concepto,
    );
  }

  @override
  List<Object?> get props => [monto, idCategoria, concepto];
}
