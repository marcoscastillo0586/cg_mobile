import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

/// Cotización usada por el servidor para convertir USD a ARS.
class ExchangeRate extends Equatable {
  /// Nombre devuelto por dolarapi.
  final String name;

  /// Centavos de ARS por 1 USD.
  final int sellCents;

  /// true si es una cotización real (recién recibida o la última guardada).
  final bool available;

  /// Cuándo se recibió (UTC, ISO) si es la última guardada y no la de ahora; null si es actual.
  final String? receivedAt;

  const ExchangeRate({required this.name, required this.sellCents, required this.available, this.receivedAt});

  /// Sin ninguna cotización conocida: los USD no se convierten (no hay cotización fija).
  static const none = ExchangeRate(name: 'sin conexión', sellCents: 0, available: false);

  bool get isStale => receivedAt != null;

  @override
  List<Object?> get props => [name, sellCents, available, receivedAt];
}

/// Cuenta con saldo: solo cuentas activas con saldo ≠ 0 (misma regla que GET /accounts/balances).
/// `id` es el id LOCAL de la cuenta.
class BalanceAccount extends Equatable {
  final int id;
  final String name;
  final Currency currency;
  final String? imageUrl;
  final String? iconRef;

  /// Saldo en la moneda de la cuenta.
  final int balanceCents;

  /// Saldo convertido a ARS; null si es USD y no hay ninguna cotización conocida.
  final int? balanceArsCents;

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

  /// Consolidado en ARS (sin las cuentas USD si no hay cotización).
  final int totalArsCents;
  final List<BalanceAccount> accounts;

  /// Por qué no se pudo obtener la cotización del servidor (null si se obtuvo o no hacía falta).
  final Object? rateError;

  const Balances({required this.until, required this.exchangeRate, required this.totalArsCents, required this.accounts, this.rateError});

  @override
  List<Object?> get props => [until, exchangeRate, totalArsCents, accounts, rateError];
}
