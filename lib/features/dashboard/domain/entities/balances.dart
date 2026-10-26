import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

/// Cuenta con saldo: solo cuentas activas con saldo ≠ 0 (misma regla que GET /accounts/balances).
/// `id` es el id LOCAL de la cuenta.
class BalanceAccount extends Equatable {
  /// Id en la base del celular (selección de cuentas del total).
  final int id;

  /// Id en el servidor: es el que filtra el historial. Null si la cuenta todavía no se envió.
  final int? serverId;
  final String name;
  final Currency currency;
  final String? imageUrl;
  final String? iconRef;

  /// Saldo en la moneda de la cuenta.
  final int balanceCents;

  const BalanceAccount({
    required this.id,
    this.serverId,
    required this.name,
    required this.currency,
    required this.imageUrl,
    required this.iconRef,
    required this.balanceCents,
  });

  @override
  List<Object?> get props => [id, serverId, name, currency, imageUrl, iconRef, balanceCents];
}

class Balances extends Equatable {
  /// Fecha de corte (`yyyy-MM-dd`) o null si es al día de hoy.
  final String? until;
  final List<BalanceAccount> accounts;

  const Balances({required this.until, required this.accounts});

  /// Monedas con al menos una cuenta (las demás no muestran total).
  Set<Currency> get currencies => {for (final a in accounts) a.currency};

  @override
  List<Object?> get props => [until, accounts];
}
