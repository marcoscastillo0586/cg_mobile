import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

/// Cotización usada por el servidor para convertir USD a ARS.
class ExchangeRate extends Equatable {
  /// Nombre devuelto por dolarapi o "sin conexión" (contingencia 1.0).
  final String name;

  /// Centavos de ARS por 1 USD.
  final int sellCents;
  final bool available;

  const ExchangeRate({required this.name, required this.sellCents, required this.available});

  @override
  List<Object?> get props => [name, sellCents, available];
}

/// Cuenta con saldo (GET /accounts/balances): solo cuentas activas con saldo ≠ 0.
class BalanceAccount extends Equatable {
  final int id;
  final String name;
  final Currency currency;
  final String? imageUrl;
  final String? iconRef;

  /// Saldo en la moneda de la cuenta.
  final int balanceCents;

  /// Saldo convertido a ARS por el servidor.
  final int balanceArsCents;

  const BalanceAccount({
    required this.id,
    required this.name,
    required this.currency,
    required this.imageUrl,
    required this.iconRef,
    required this.balanceCents,
    required this.balanceArsCents,
  });

  @override
  List<Object?> get props => [id, name, currency, imageUrl, iconRef, balanceCents, balanceArsCents];
}

class Balances extends Equatable {
  /// Fecha de corte (`yyyy-MM-dd`) o null si es al día de hoy.
  final String? until;
  final ExchangeRate exchangeRate;
  final int totalArsCents;
  final List<BalanceAccount> accounts;

  const Balances({required this.until, required this.exchangeRate, required this.totalArsCents, required this.accounts});

  @override
  List<Object?> get props => [until, exchangeRate, totalArsCents, accounts];
}
