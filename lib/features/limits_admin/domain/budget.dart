import 'package:equatable/equatable.dart';

class BudgetRef extends Equatable {
  final int id;
  final String name;
  const BudgetRef(this.id, this.name);

  @override
  List<Object?> get props => [id, name];
}

/// Presupuesto (BudgetDto). Consumo, resto, porcentaje y vencimiento los calcula el
/// servidor con la regla de F6.2/F6.3; la app no los recalcula.
class Budget extends Equatable {
  final int id;

  /// `yyyy-MM-dd`.
  final String startDate;
  final String endDate;
  final int limitCents;
  final int consumedCents;

  /// límite − consumo (negativo = excedente).
  final int remainingCents;

  /// consumo × 100 / límite truncado a 2 decimales; null si el límite es 0.
  final num? percent;

  /// hoy >= fecha hasta: habilita "Renovar".
  final bool dueForRenewal;
  final List<BudgetRef> categories;
  final List<BudgetRef> accounts;
  final int? version;

  const Budget({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.limitCents,
    required this.consumedCents,
    required this.remainingCents,
    required this.percent,
    required this.dueForRenewal,
    required this.categories,
    required this.accounts,
    this.version,
  });

  bool get exceeded => remainingCents < 0;

  /// Nombre como en la web: categorías ordenadas por nombre.
  String get title => (categories.map((c) => c.name).toList()..sort()).join(', ');

  @override
  List<Object?> get props =>
      [id, startDate, endDate, limitCents, consumedCents, remainingCents, percent, dueForRenewal, categories, accounts, version];
}
