import 'package:equatable/equatable.dart';
import '../../../core/money/money.dart';

class BudgetRef extends Equatable {
  /// Id LOCAL de la categoría o cuenta.
  final int id;
  final String name;
  const BudgetRef(this.id, this.name);

  @override
  List<Object?> get props => [id, name];
}

/// Presupuesto (límite de gasto) calculado desde la base local con la regla del servidor
/// (budgets.service.ts): consumo = Σ(−monto) de egresos en el período ("hasta" incluido
/// completo) y en las cuentas/categorías del límite; porcentaje truncado a 2 decimales;
/// vencido si hoy (Buenos Aires) >= "hasta". `id` es el id LOCAL.
class Budget extends Equatable {
  final int id;
  final int? serverId;

  /// `yyyy-MM-dd`.
  final String startDate;
  final String endDate;
  final int limitCents;
  final int consumedCents;

  /// consumo × 10000 / límite, truncado (centésimos de porcentaje); null si el límite es 0.
  final int? percentHundredths;

  /// hoy >= fecha hasta: habilita "Renovar".
  final bool dueForRenewal;
  final List<BudgetRef> categories;
  final List<BudgetRef> accounts;

  /// Moneda del límite (la de sus cuentas); null si mezcla monedas (límites anteriores a esa regla).
  final Currency? currency;
  final int? version;

  const Budget({
    required this.id,
    this.serverId,
    required this.startDate,
    required this.endDate,
    required this.limitCents,
    required this.consumedCents,
    required this.percentHundredths,
    required this.dueForRenewal,
    required this.categories,
    required this.accounts,
    this.currency,
    this.version,
  });

  /// límite − consumo (negativo = excedente).
  int get remainingCents => limitCents - consumedCents;

  /// Para mostrar (Money.percent): 7550 → 75.5.
  num? get percent => percentHundredths == null ? null : percentHundredths! / 100;

  bool get exceeded => remainingCents < 0;

  /// Nombre como en la web: categorías ordenadas por nombre.
  String get title => (categories.map((c) => c.name).toList()..sort()).join(', ');

  @override
  List<Object?> get props =>
      [id, serverId, startDate, endDate, limitCents, consumedCents, percentHundredths, dueForRenewal, categories, accounts, currency, version];
}
