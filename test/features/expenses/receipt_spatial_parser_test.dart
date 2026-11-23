// Extracción de encabezado, renglones y total sobre filas ya armadas, y la lectura completa desde un
// RecognizedText con la forma que entrega ML Kit (construido a mano: el OCR real sólo corre en el celular).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

SpatialRow _row(int i, String text, [String? right]) => SpatialRow(
      index: i,
      topY: i * 30,
      bottomY: i * 30 + 20,
      elements: [
        SpatialTextElement(text: right == null ? text : text.replaceAll(right, '').trim(), rect: Rect.fromLTRB(10, i * 30.0, 300, i * 30.0 + 20)),
        if (right != null) SpatialTextElement(text: right, rect: Rect.fromLTRB(320, i * 30.0, 500, i * 30.0 + 20)),
      ],
      fullText: text,
      fotoOrigen: i < 5 ? 1 : 2,
    );

TextLine _line(String text, double left, double top) => TextLine(
      text: text,
      elements: const [],
      boundingBox: Rect.fromLTWH(left, top, 200, 20),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

void main() {
  test('encabezado: comercio, sucursal, dirección, CUIT, fecha y hora (primera aparición)', () {
    final r = ReceiptSpatialParser.parseRows([
      _row(1, 'C.I.C.S.A. COTO'),
      _row(2, 'SUC 145 PALERMO'),
      _row(3, 'AVDA SANTA FE 1234'),
      _row(4, 'CUIT 30-54808315-6 FECHA 02/10/2026 HORA 18:30:05'),
      _row(5, 'Calle Falsa 123 02/11/2026 19:00'),
    ]);
    expect([r.comercio, r.sucursal, r.direccion, r.cuit, r.fecha, r.hora],
        ['COTO', 'SUC 145 PALERMO', 'AVDA SANTA FE 1234', '30-54808315-6', '02/10/2026', '18:30:05']);
    expect(r.items, isEmpty);
    final none = ReceiptSpatialParser.parseRows([_row(1, 'SUPER X')]);
    expect([none.comercio, none.sucursal, none.direccion, none.cuit, none.fecha, none.hora], List.filled(6, null));
  });

  test('renglón en una sola fila (nombre y precio); si sigue una fila de código, el precio es de esa', () {
    final r = ReceiptSpatialParser.parseRows([
      _row(1, 'PAN FRANCES 1500,00', '1500,00'),
      _row(2, 'LECHE ENTERA'),
      _row(3, '0000015889 07790040008175 2965,99', '2965,99'),
      _row(4, '2 x 1250,00'),
      _row(5, 'TOTAL 4465,99', '4465,99'),
      _row(6, 'GASEOSA 999,00', '999,00'),
    ]);
    expect([for (final i in r.items) (i.descripcion, i.montoNeto, i.renglon)], [('PAN FRANCES', 150000, 1), ('LECHE ENTERA', 296599, 2)]);
    expect(r.totales.totalPagado, 446599); // lo que sigue al total no se lee
  });

  test('detalle adicional antes del código (cantidad o %) y nombre buscado hacia atrás; descuento mayor al precio no se aplica', () {
    final r = ReceiptSpatialParser.parseRows([
      _row(1, 'QUESO CREMOSO'),
      _row(2, '3 x 1000,00'),
      _row(3, '0000098765 07790012345678 3000,00', '3000,00'),
      _row(4, 'MARCAS -3500,00', '-3500,00'),
      _row(5, 'YERBA PLAYADITO'),
      _row(6, '25% OFF'),
      _row(7, '0000011111 07790000000001 1200,00', '1200,00'),
    ]);
    expect(r.items[0].descripcion, 'QUESO CREMOSO');
    expect(r.items[0].detalleAdicional, '3 x 1000,00');
    expect([r.items[0].descuento, r.items[0].montoNeto], [0, 300000]);
    expect(r.items[1].descripcion, 'YERBA PLAYADITO');
    expect(r.items[1].detalleAdicional, '25% OFF');
    expect(r.totales.totalPagado, 420000); // sin total impreso: suma de netos
  });

  test('desde RecognizedText: líneas de bloques → filas → renglones y total', () {
    final text = RecognizedText(text: '', blocks: [
      TextBlock(
        text: '',
        lines: [_line('OBLEA RELLENA', 10, 60), _line('0000015889 07790040008175', 10, 100), _line('2965,99', 320, 102), _line('  ', 10, 130)],
        boundingBox: Rect.zero,
        recognizedLanguages: const [],
        cornerPoints: const [],
      ),
      TextBlock(
        text: '',
        lines: [_line('TOTAL', 10, 200), _line('2965,99', 320, 201)],
        boundingBox: Rect.zero,
        recognizedLanguages: const [],
        cornerPoints: const [],
      ),
    ]);
    final r = ReceiptSpatialParser.parseRecognizedText(text);
    expect([for (final i in r.items) (i.descripcion, i.montoBruto)], [('OBLEA RELLENA', 296599)]);
    expect(r.totalDetectadoCents, 296599);
    expect(r.filasConsolidadas.map((f) => f.fullText), ['OBLEA RELLENA', '0000015889 07790040008175 2965,99', 'TOTAL 2965,99']);
  });

  test('sin filas: ticket vacío', () {
    final r = ReceiptSpatialParser.parseRows([]);
    expect([r.items, r.totales.subtotalBruto, r.totales.totalPagado], [isEmpty, 0, 0]);
  });
}
