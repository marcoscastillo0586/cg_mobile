import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/money/money.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/qr_ticket.dart';
import '../domain/entities/ticket_parse_result.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>((ref) => TicketsRepository(ref.watch(dioClientProvider)));

/// Tickets digitales por QR: lectura (`POST /tickets/parse-url`) y confirmación
/// (`POST /tickets/confirm`). Solo con conexión: el servidor descarga y analiza el ticket.
/// La confirmación es idempotente por `clientSyncId` (un reintento no duplica el egreso).
class TicketsRepository {
  final DioClient _client;
  TicketsRepository(this._client);

  Future<QrTicket> parseUrl(String url) async => parse(await _client.post('/tickets/parse-url', data: {'url': url}));

  /// Id del comprobante creado o, si ese clientSyncId ya estaba registrado, el existente (`duplicate`).
  Future<({int headerId, bool duplicate})> confirm(QrTicketConfirmation c) async {
    final body = await _client.post('/tickets/confirm', data: c.toJson());
    if (body is! Map<String, dynamic> || body['headerId'] is! int) throw _bad('tickets/confirm');
    return (headerId: body['headerId'] as int, duplicate: body['duplicate'] == true);
  }

  /// El servidor responde ahora (`GET /health`, público). Se usa antes de abrir "Escanear ticket",
  /// que solo funciona con conexión. Cualquier error cuenta como no disponible.
  Future<bool> serverAvailable() async {
    try {
      await _client.get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5), sendTimeout: const Duration(seconds: 5)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fotos de un ticket por pedido (el servidor rechaza más).
  static const maxImages = 5;

  /// Espera de la lectura por foto: mayor que el tiempo máximo que el servidor espera a Gemini
  /// (`GEMINI_TICKET_TIMEOUT_MS`, hoy 180 s) más un margen. Solo esta llamada: los tiempos generales no cambian.
  static const readImagesTimeout = Duration(seconds: 210);
  static const readImagesSendTimeout = Duration(seconds: 120);

  /// Ticket leído desde las capturas del escáner (`POST /tickets/read-images`, en orden) con IA en el
  /// servidor. Devuelve lo mismo que la lectura en el celular, para la misma revisión y el mismo
  /// guardado; la IA no confirma ni registra nada.
  Future<TicketParseResult> readImages(List<String> imagePaths, {CancelToken? cancelToken}) async {
    final form = FormData();
    for (final (i, path) in imagePaths.indexed) {
      form.files.add(MapEntry('images', await MultipartFile.fromFile(path, filename: 'parte${i + 1}.jpg', contentType: DioMediaType('image', 'jpeg'))));
    }
    final body = await _client.post(
      '/tickets/read-images',
      data: form,
      options: Options(receiveTimeout: readImagesTimeout, sendTimeout: readImagesSendTimeout),
      cancelToken: cancelToken,
    );
    return parseImageTicket(body, imagePaths);
  }

  /// `ImageTicketDto` → el mismo resultado que produce la lectura con ML Kit (renglones con su importe
  /// neto y total impreso). Comercio, fecha y número no se usan, igual que en la lectura del celular.
  static TicketParseResult parseImageTicket(Object? json, List<String> imagePaths) {
    if (json is! Map<String, dynamic>) throw _bad('ticket');
    final items = json['items'];
    if (items is! List) throw _bad('ticket.items');
    final total = json['totalPrintedCents'];
    return TicketParseResult(
      readerName: 'gemini',
      items: [
        for (final i in items.cast<Map<String, dynamic>>())
          ParsedTicketItem(nombre: i['description'] as String? ?? '', precioCents: Money.centsFrom(i['netCents'], 'netCents')),
      ],
      totalDetectadoCents: total == null ? null : Money.centsFrom(total, 'totalPrintedCents'),
      rawTexts: const [],
      imagePaths: imagePaths,
    );
  }

  /// Comprobante completo (`GET /movements/:id`, mismo formato que el pull, sin version/clientId).
  Future<Map<String, dynamic>> movement(int id) async {
    final body = await _client.get('/movements/$id');
    if (body is! Map<String, dynamic> || body['id'] != id) throw _bad('movements/$id');
    return body;
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
