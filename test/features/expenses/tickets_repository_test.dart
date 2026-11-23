// Contrato del ticket por QR y del comprobante confirmado, con respuestas SIMULADAS.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/features/expenses/data/tickets_repository.dart';

class _Api implements HttpClientAdapter {
  final Object body;
  _Api(this.body);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

Matcher _unexpected(String field) =>
    throwsA(isA<ServerException>().having((e) => e.code, 'code', 'UNEXPECTED_RESPONSE').having((e) => e.message, 'message', contains(field)));

void main() {
  TicketsRepository repo(Object body) => TicketsRepository(DioClient(adapter: _Api(body))..dio.options.baseUrl = 'http://api.fake/api/v1');

  test('comprobante confirmado: tiene que ser el pedido', () async {
    expect(await repo({'id': 9, 'type': 2}).movement(9), {'id': 9, 'type': 2});
    await expectLater(repo({'id': 8}).movement(9), _unexpected('movements/9'));
    await expectLater(repo([1]).movement(9), _unexpected('movements/9'));
  });

  test('ticket por QR: renglones y avisos; lo que no tiene la forma esperada se rechaza o se ignora', () {
    final t = TicketsRepository.parse({
      'reader': 'coto', 'merchant': 'COTO', 'itemsTotalCents': 1500, 'totalPrintedCents': null,
      'warnings': [{'code': 'NO_TOTAL', 'message': 'm'}, 'x', {'itemIndex': 0}],
      'items': [{'description': 'PAN', 'netCents': 1500, 'unitPriceCents': 750, 'suggestedCategoryId': 3, 'doubtful': true}, <String, dynamic>{'netCents': 0}],
    });
    expect((t.reader, t.merchant, t.totalPrintedCents, t.itemsTotalCents), ('coto', 'COTO', null, 1500));
    expect([for (final w in t.warnings) (w.code, w.itemIndex)], [('NO_TOTAL', null), ('', 0)]);
    expect((t.items.first.description, t.items.first.unitPriceCents, t.items.first.suggestedCategoryServerId, t.items.first.doubtful), ('PAN', 750, 3, true));
    expect((t.items.last.description, t.items.last.netCents, t.items.last.doubtful), ('', 0, false));
    expect(() => TicketsRepository.parse('x'), _unexpected('ticket'));
    expect(() => TicketsRepository.parse({'items': 'x'}), _unexpected('ticket.items'));
    expect(() => TicketsRepository.parse({'itemsTotalCents': 0, 'items': [<String, dynamic>{}]}), _unexpected('netCents'));
  });
}
