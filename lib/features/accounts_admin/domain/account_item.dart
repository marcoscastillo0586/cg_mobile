import 'package:equatable/equatable.dart';
import '../../../core/money/money.dart';

/// Cuenta de la base local: activas e inactivas, con saldo y cantidad de renglones.
/// `id` es el id LOCAL; `serverId` es null hasta que el alta se sincroniza.
class AccountItem extends Equatable {
  final int id;
  final int? serverId;
  final String name;
  final Currency currency;
  final bool active;
  final String? imageUrl;
  final String? iconRef;
  final int balanceCents;
  final int movementsCount;

  const AccountItem({
    required this.id,
    this.serverId,
    required this.name,
    required this.currency,
    required this.active,
    required this.imageUrl,
    required this.iconRef,
    required this.balanceCents,
    required this.movementsCount,
  });

  @override
  List<Object?> get props => [id, serverId, name, currency, active, imageUrl, iconRef, balanceCents, movementsCount];
}
