import 'package:equatable/equatable.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/account_entity.dart';
import 'category_entity.dart';

class ExpenseFormDataEntity extends Equatable {
  final List<AccountEntity> lugares;
  final List<CategoryEntity> categorias;
  final List<String> conceptos;

  const ExpenseFormDataEntity({
    required this.lugares,
    required this.categorias,
    required this.conceptos,
  });

  @override
  List<Object?> get props => [lugares, categorias, conceptos];
}
