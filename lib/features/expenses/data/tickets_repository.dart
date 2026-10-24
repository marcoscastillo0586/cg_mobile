import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/qr_ticket.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) => TicketsRepository(ref.watch(dioClientProvider)));

/// Tickets digitales por QR: lectura (`POST /tickets/parse-url`) y confirmación
/// (`POST /tickets/confirm`). Solo con conexión: el servidor descarga y analiza el ticket.
/// La confirmación es idempotente por `clientSyncId` (un reintento no duplica el egreso).
class TicketsRepository {
  final DioClient _client;
  TicketsRepository(this._client);

  Future<QrTicket> parseUrl(String url) async => parse(await _client.post('/tickets/parse-url', data: {'url': url}));

  /// Devuelve el id del comprobante creado (o el existente, si era un reintento).
  Future<int> confirm(QrTicketConfirmation c) async {
    final body = await _client.post('/tickets/confirm', data: c.toJson());
    if (body is! Map<String, dynamic> || body['headerId'] is! int) throw _bad('tickets/confirm');
    return body['headerId'] as int;
  }

  static QrTicket parse(Object? json) {
    if (json is! Map<String, dynamic>) throw _bad('ticket');
    final items = json['items'];
    if (items is! List) throw _bad('ticket.items');
    int? cents(Object? v, String f) => v == null ? null : Money.centsFrom(v, f);
    return QrTicket(
      reader: json['reader'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      branch: json['branch'] as String?,
      cuit: json['cuit'] as String?,
      address: json['address'] as String?,
      receiptNumber: json['receiptNumber'] as String?,
      receiptDate: json['receiptDate'] as String?,
      isoDate: json['isoDate'] as String?,
      receiptTime: json['receiptTime'] as String?,
      totalPrintedCents: cents(json['totalPrintedCents'], 'totalPrintedCents'),
      itemsTotalCents: Money.centsFrom(json['itemsTotalCents'], 'itemsTotalCents'),
      warnings: [
        for (final w in (json['warnings'] as List? ?? const []))
          if (w is Map<String, dynamic>) QrTicketWarning(w['code'] as String? ?? '', w['message'] as String? ?? '', w['itemIndex'] as int?),
      ],
      items: [
        for (final i in items.cast<Map<String, dynamic>>())
          QrTicketItem(
            description: i['description'] as String? ?? '',
            plu: i['plu'] as String?,
            unitPriceCents: cents(i['unitPriceCents'], 'unitPriceCents'),
            netCents: Money.centsFrom(i['netCents'], 'netCents'),
            suggestedCategoryServerId: i['suggestedCategoryId'] as int?,
            doubtful: i['doubtful'] == true,
          ),
      ],
    );
  }

  static ServerException _bad(String field) => ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
