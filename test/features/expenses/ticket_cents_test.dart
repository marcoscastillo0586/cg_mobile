// Importes de tickets en centavos enteros: parser espacial (filas SINTÉTICAS con el texto de
// la foto test/fixtures/fotos/1.jpeg) y ticket QR (JSON con la forma de ParsedTicketDto).
// El OCR real (ML Kit) solo corre en el celular.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';
import 'package:gastos_mobile/features/expenses/data/tickets_repository.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/qr_ticket.dart';

SpatialRow _row(int i, String text, [String? right]) => SpatialRow(
      index: i,
      topY: i * 30,
      bottomY: i * 30 + 20,
      elements: [
        SpatialTextElement(text: right == null ? text : text.replaceAll(right, '').trim(), rect: Rect.fromLTRB(10, i * 30.0, 300, i * 30.0 + 20)),
        if (right != null) SpatialTextElement(text: right, rect: Rect.fromLTRB(320, i * 30.0, 500, i * 30.0 + 20)),
      ],
      fullText: text,
    );

void main() {
  test('parser espacial: bruto, descuento y neto en centavos exactos (renglones de la foto 1)', () {
    final r = ReceiptSpatialParser.parseRows([
      _row(1, 'OBLEA RELLENA OPERAPAQ 220 GRM'),
      _row(2, '0000015889 07790040008175 2965,99', '2965,99'),
      _row(3, '5 *35% MARCAS [A] -1038,10', '-1038,10'),
      _row(4, '=MORCILLA ROSCA CIUDAD DEL LAGO X KG'),
      _row(5, '0000036505 02536505004109 3444,00', '3444,00'),
      _row(6, 'TOTAL 4371,89', '4371,89'),
    ]);
    expect(r.items.map((i) => (i.montoBruto, i.descuento, i.montoNeto)), [(296599, 103810, 192789), (344400, 0, 344400)]);
    expect(r.totalDetectadoCents, 437189);
    expect((r.totales.subtotalBruto, r.totales.totalDescuentos), (296599 + 344400, 103810));
  });

  test('montos con miles y punto decimal, sin pasar por double', () {
    final r = ReceiptSpatialParser.parseRows([
      _row(1, 'TELEVISOR'),
      _row(2, '0000099999 07790000000001 1.234.567,89', '1.234.567,89'),
      _row(3, 'PAN'),
      _row(4, '0000099998 07790000000002 0.10', '0.10'),
    ]);
    expect(r.items.map((i) => i.montoNeto), [123456789, 10]);
  });

  test('QR: ParsedTicketDto a centavos y payload de /tickets/confirm con ids del servidor', () {
    final t = TicketsRepository.parse({
      'reader': 'coto-estructurado', 'sourceUrl': 'https://apps01.coto.com.ar/x', 'merchant': 'COTO', 'branch': 'SUC131',
      'cuit': '30-54808315-6', 'address': null, 'receiptNumber': '131-09962018', 'receiptDate': '02/10/2026', 'isoDate': '2026-10-02',
      'receiptTime': '17:32', 'subtotalCents': 16959797, 'savingsCents': 2475457, 'totalPrintedCents': 14484341, 'itemsTotalCents': 14484340,
      'payments': <Object>[],
      'warnings': [{'code': 'SUM_MISMATCH', 'message': 'diferencia 0,01'}],
      'items': [
        {'description': 'GALL.RELLENA OPERA', 'plu': '00000000015889', 'ean': null, 'quantity': 1, 'unitPriceCents': 296599,
         'grossCents': 296599, 'discountCents': 103810, 'netCents': 192789, 'offer': null, 'imageDataUri': null, 'suggestedCategoryId': 7, 'doubtful': false},
      ],
    });
    expect((t.items.single.netCents, t.items.single.suggestedCategoryServerId, t.totalPrintedCents, t.itemsTotalCents), (192789, 7, 14484341, 14484340));
    expect(t.generalConcept, 'COTO SUC131');
    final json = QrTicketConfirmation(
      accountServerId: 2, date: '2026-10-02', generalConcept: 'COTO SUC131', ticket: t, clientSyncId: 'cid-0001',
      items: const [QrTicketConfirmItem(concept: 'GALL.RELLENA OPERA', categoryServerId: 7, amountCents: 192789, plu: '00000000015889', unitPriceCents: 296599)],
    ).toJson();
    expect(json['items'], [
      {'concept': 'GALL.RELLENA OPERA', 'categoryId': 7, 'amount': '1927.89', 'plu': '00000000015889', 'unitPrice': '2965.99'},
    ]);
    expect((json['ticket']! as Map)['totalReadCents'], 14484341);
    expect(json['clientSyncId'], 'cid-0001');
  });
}
