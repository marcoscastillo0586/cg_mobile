import 'package:equatable/equatable.dart';
import '../../../core/money/money.dart';
import '../../categories_admin/domain/category_item.dart';

/// Tipo de comprobante de la API.
enum MovementType {
  income(1),
  expense(2),
  transfer(3);

  final int code;
  const MovementType(this.code);

  static MovementType parse(Object? v) => MovementType.values.firstWhere(
        (t) => t.code == v,
        orElse: () => throw ArgumentError('Tipo de movimiento desconocido: $v'),
      );
}

/// Renglón (MovementDetailDto). [amountCents] con signo contable (egresos negativos).
class MovementDetailItem extends Equatable {
  final int id;
  final int accountId;
  final String accountName;
  final Currency currency;
  final int? categoryId;
  final String? categoryName;
  final CategoryRole? categoryRole;
  final String? concept;
  final int amountCents;
  final String? plu;
  final int? unitPriceCents;
  final String? imageUrl;

  const MovementDetailItem({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.currency,
    required this.categoryId,
    required this.categoryName,
    required this.categoryRole,
    required this.concept,
    required this.amountCents,
    required this.plu,
    required this.unitPriceCents,
    required this.imageUrl,
  });

  @override
  List<Object?> get props =>
      [id, accountId, accountName, currency, categoryId, categoryName, categoryRole, concept, amountCents, plu, unitPriceCents, imageUrl];
}

/// Comprobante (MovementDto) con sus renglones.
class MovementItem extends Equatable {
  final int id;
  final MovementType type;

  /// `yyyy-MM-dd HH:mm:ss`, hora local AR (sin zona).
  final String occurredAt;
  final String? generalConcept;
  final List<String> accountNames;

  /// Importe mostrado: suma de los renglones que cumplen el filtro (egresos negativos);
  /// en transferencias, el importe transferido (positivo).
  final int amountCents;
  final int detailsCount;
  final bool partialDetails;
  final List<MovementDetailItem> details;
  final int? fromAccountId;
  final int? toAccountId;

  /// Quién lo cargó (el único que lo edita o lo borra) y su nombre para mostrar actual.
  final int? createdByUserId;
  final String? createdByName;

  const MovementItem({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.generalConcept,
    required this.accountNames,
    required this.amountCents,
    required this.detailsCount,
    required this.partialDetails,
    required this.details,
    required this.fromAccountId,
    required this.toAccountId,
    this.createdByUserId,
    this.createdByName,
  });

  /// Moneda del comprobante (la de su primer renglón; la API no mezcla monedas).
  Currency get currency => details.isEmpty ? Currency.ars : details.first.currency;

  @override
  List<Object?> get props =>
      [id, type, occurredAt, generalConcept, accountNames, amountCents, detailsCount, partialDetails, details, fromAccountId, toAccountId, createdByUserId, createdByName];
}

class MovementsPage extends Equatable {
  final List<MovementItem> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  /// |Σ importes| de todos los resultados filtrados.
  final int filteredTotalCents;

  const MovementsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
    required this.filteredTotalCents,
  });

  @override
  List<Object?> get props => [items, total, limit, offset, hasMore, filteredTotalCents];
}
