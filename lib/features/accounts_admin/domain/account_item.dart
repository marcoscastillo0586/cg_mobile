import 'package:equatable/equatable.dart';
import '../../../core/money/money.dart';

/// Cuenta (AccountDto): activas e inactivas, con saldo y cantidad de movimientos.
class AccountItem extends Equatable {
  final int id;
  final String name;
  final Currency currency;
  final bool active;
  final String? imageUrl;
  final String? iconRef;
  final int balanceCents;
  final int movementsCount;

  /// Versión del servidor (solo la trae /sync/pull; null en las respuestas REST).
  final int? version;

  const AccountItem({
    required this.id,
    required this.name,
    required this.currency,
    required this.active,
    required this.imageUrl,
    required this.iconRef,
    required this.balanceCents,
    required this.movementsCount,
    this.version,
  });

  @override
  List<Object?> get props => [id, name, currency, active, imageUrl, iconRef, balanceCents, movementsCount, version];
}
