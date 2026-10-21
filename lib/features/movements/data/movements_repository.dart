import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../../categories_admin/domain/category_item.dart';
import '../domain/movement_item.dart';

final movementsRepositoryProvider = Provider<MovementsRepository>((ref) {
  return MovementsRepository(ref.watch(dioClientProvider));
});

/// Filtros de GET /movements. Fechas `yyyy-MM-dd`; sin fechas el servidor devuelve
/// los últimos 60 (F7.1). [q] busca por texto o monto (F7.4/F7.9).
class MovementsQuery {
  final String? from;
  final String? to;
  final List<int> accountIds;
  final List<int> categoryIds;
  final String? q;
  final int limit;
  final int offset;

  const MovementsQuery({
    this.from,
    this.to,
    this.accountIds = const [],
    this.categoryIds = const [],
    this.q,
    this.limit = 50,
    this.offset = 0,
  });

  Map<String, dynamic> toQuery() => {
        if (from != null && from!.isNotEmpty) 'from': from,
        if (to != null && to!.isNotEmpty) 'to': to,
        if (accountIds.isNotEmpty) 'accountIds': accountIds.join(','),
        if (categoryIds.isNotEmpty) 'categoryIds': categoryIds.join(','),
        if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
        'limit': limit,
        'offset': offset,
      };
}

/// Historial de movimientos. Solo lectura (edición y borrado: etapa 7).
class MovementsRepository {
  final DioClient _client;
  MovementsRepository(this._client);

  Future<MovementsPage> getMovements(MovementsQuery query) async {
    final data = await _client.get('/movements', queryParameters: query.toQuery());
    if (data is! Map<String, dynamic>) throw _bad('movements');
    final items = data['items'];
    if (items is! List) throw _bad('items');
    return MovementsPage(
      items: items.map(parseMovement).toList(),
      total: _int(data['total'], 'total'),
      limit: _int(data['limit'], 'limit'),
      offset: _int(data['offset'], 'offset'),
      hasMore: data['hasMore'] == true,
      filteredTotalCents: Money.centsFrom(data['filteredTotalCents'], 'filteredTotalCents'),
    );
  }

  Future<MovementItem> getMovement(int id) async => parseMovement(await _client.get('/movements/$id'));

  static MovementItem parseMovement(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('movement');
    final details = json['details'];
    if (details is! List) throw _bad('details');
    final names = json['accountNames'];
    try {
      return MovementItem(
        id: _int(json['id'], 'movement.id'),
        type: MovementType.parse(json['type']),
        occurredAt: json['occurredAt'] as String? ?? (throw _bad('occurredAt')),
        generalConcept: json['generalConcept'] as String?,
        accountNames: names is List ? names.map((e) => e.toString()).toList() : const [],
        amountCents: Money.centsFrom(json['amountCents'], 'movement.amountCents'),
        detailsCount: _int(json['detailsCount'], 'detailsCount'),
        partialDetails: json['partialDetails'] == true,
        details: details.map(_detail).toList(),
        fromAccountId: json['fromAccountId'] as int?,
        toAccountId: json['toAccountId'] as int?,
      );
    } on ArgumentError catch (e) {
      throw ServerException('Respuesta inesperada del servidor (${e.message})', null, 'UNEXPECTED_RESPONSE');
    }
  }

  static MovementDetailItem _detail(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('detail');
    final unit = json['unitPriceCents'];
    return MovementDetailItem(
      id: _int(json['id'], 'detail.id'),
      accountId: _int(json['accountId'], 'detail.accountId'),
      accountName: json['accountName'] as String? ?? '',
      currency: Currency.parse(json['currency']),
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      categoryRole: CategoryRole.parse(json['categoryRole']),
      concept: json['concept'] as String?,
      amountCents: Money.centsFrom(json['amountCents'], 'detail.amountCents'),
      plu: json['plu'] as String?,
      unitPriceCents: unit == null ? null : Money.centsFrom(unit, 'detail.unitPriceCents'),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  static int _int(Object? v, String field) => v is int ? v : throw _bad(field);

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
