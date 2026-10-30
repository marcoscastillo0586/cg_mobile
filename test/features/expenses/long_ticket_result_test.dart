// Ticket largo R4: las filas unidas pasan al parser existente y la suma de los renglones (con sus
// descuentos) se verifica contra el total IMPRESO. Filas SINTÉTICAS; el OCR real solo corre en el celular.
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/mlkit_ticket_reader.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';
import 'package:gastos_mobile/features/expenses/data/services/ticket_row_merger.dart';

List<SpatialRow> _part(int foto, List<String> texts) => [
      for (final (i, t) in texts.indexed)
        SpatialRow(
          index: i + 1,
          topY: i * 30,
          bottomY: i * 30 + 20,
          elements: [SpatialTextElement(text: t, rect: Rect.fromLTWH(10, i * 30.0, 500, 20))],
          fullText: t,
          fotoOrigen: foto,
        ),
    ];

void main() {
  // Parte 1: cabecera y primeros productos; parte 2: últimos productos y totales; se superponen 3 filas.
  final parte1 = _part(1, [
    'COTO C.I.C.S.A.',
    'KRACHITOS',
    '0000012345 07794520868969 2965,99',
    '5 *35% MARCAS [A] -1038,10',
    'MORCILLA ROSCA',
  ]);
  final parte2 = _part(2, [
    '0000012345 07794520868969 2965,99',
    '5 *35% MARCAS [A] -1038,10',
    'MORCILLA ROSCA',
    '0000036505 02536505004109 3444,00',
    'KRACHITOS',
    '0000012399 07794520869027 1000,00',
    'TOTAL 6371,89',
  ]);

  test('una sola captura para el parser: renglones con descuento y total impreso', () {
    final merged = const TicketRowMerger().merge([parte1, parte2]);
    final r = MlKitTicketReader().longTicketResult(merged, const ['p1.jpg', 'p2.jpg']);

    expect(r.items.map((i) => (i.nombre, i.precioCents)), [
      ('KRACHITOS', 296599 - 103810), // neto: bruto menos su descuento
      ('MORCILLA ROSCA', 344400),
      ('KRACHITOS', 100000), // mismo nombre, otro código: renglón propio
    ]);
    expect(r.totalDetectadoCents, 637189);
    // 192789 + 344400 + 100000 = 637189: renglones + descuentos = total impreso.
    expect(r.tieneDiferenciaTotal, isFalse);
    expect(r.imagePaths, ['p1.jpg', 'p2.jpg']);
  });

  test(r'diferencia con el total impreso mayor a $ 0,05: se avisa (la de $ 0,01 por redondeo no)', () {
    TicketRowMerger merger() => const TicketRowMerger();
    final con1Centavo = _part(2, [...parte2.take(6).map((r) => r.fullText), 'TOTAL 6371,90']);
    final con6Centavos = _part(2, [...parte2.take(6).map((r) => r.fullText), 'TOTAL 6371,95']);
    final reader = MlKitTicketReader();

    expect(reader.longTicketResult(merger().merge([parte1, con1Centavo]), const []).tieneDiferenciaTotal, isFalse);
    expect(reader.longTicketResult(merger().merge([parte1, con6Centavos]), const []).tieneDiferenciaTotal, isTrue);
  });

  test('sin fila TOTAL no se inventa el total (no se compara la suma consigo misma)', () {
    final sinTotal = _part(2, parte2.take(6).map((r) => r.fullText).toList());
    final r = MlKitTicketReader().longTicketResult(const TicketRowMerger().merge([parte1, sinTotal]), const []);

    expect(r.totalDetectadoCents, isNull);
    expect(r.tieneDiferenciaTotal, isFalse);
  });
}
