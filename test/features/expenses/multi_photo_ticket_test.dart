// Lectura de tickets con ML Kit, sin ML Kit: armado de filas a partir de los textos de una foto y unión de varias
// fotos quitando el tramo repetido entre una y la siguiente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';

SpatialTextElement _el(String text, double left, double top, [double height = 20]) =>
    SpatialTextElement(text: text, rect: Rect.fromLTWH(left, top, 100, height));

SpatialRow _row(String text, int foto, [int index = 1]) =>
    SpatialRow(index: index, topY: index * 30, bottomY: index * 30 + 20, elements: [_el(text, 0, index * 30.0)], fullText: text, fotoOrigen: foto);

List<String> _texts(List<SpatialRow> rows) => [for (final r in rows) r.fullText];

void main() {
  group('filas de una foto', () {
    test('textos a la misma altura forman una fila, ordenados de izquierda a derecha', () {
      final rows = ReceiptSpatialParser.rowsFromElements([
        _el('2965,99', 320, 103),
        _el('TOTAL', 10, 200),
        _el('0000015889', 10, 100),
        _el('4371,89', 320, 198),
        _el('OBLEA', 10, 60),
      ], 2);
      expect(_texts(rows), ['OBLEA', '0000015889 2965,99', 'TOTAL 4371,89']);
      expect([for (final r in rows) r.index], [1, 2, 3]);
      expect(rows[1].fotoOrigen, 2);
      expect([rows[1].topY, rows[1].bottomY], [100, 123]);
    });

    test('la tolerancia vertical depende de la altura típica del texto (mínimo 8 px)', () {
      // Altura 20 → tolerancia 9: a 9 px es la misma fila, a 10 px otra.
      expect(ReceiptSpatialParser.rowsFromElements([_el('A', 0, 0), _el('B', 50, 9)], 1), hasLength(1));
      expect(ReceiptSpatialParser.rowsFromElements([_el('A', 0, 0), _el('B', 50, 10)], 1), hasLength(2));
      // Altura 4 → tolerancia mínima de 8 px.
      expect(ReceiptSpatialParser.rowsFromElements([_el('A', 0, 0, 4), _el('B', 50, 8, 4)], 1), hasLength(1));
    });

    test('sin textos, sin filas', () {
      expect(ReceiptSpatialParser.rowsFromElements([], 1), isEmpty);
    });
  });

  group('unión de fotos', () {
    test('quita las filas repetidas en el borde (2 a 6 consecutivas, sin importar mayúsculas) y renumera', () {
      final merged = ReceiptSpatialParser.mergePhotos([
        [_row('QUESO 8602,00', 1), _row('HAMBURGUESA PATY', 1, 2), _row('0000098765 16595,72', 1, 3)],
        [_row('hamburguesa paty', 2), _row('0000098765 16595,72', 2, 2), _row('TOTAL 25197,72', 2, 3)],
      ]);
      expect(_texts(merged), ['QUESO 8602,00', 'HAMBURGUESA PATY', '0000098765 16595,72', 'TOTAL 25197,72']);
      expect([for (final r in merged) r.index], [1, 2, 3, 4]);
      expect([for (final r in merged) r.fotoOrigen], [1, 1, 1, 2]);
    });

    test('una sola fila igual no es solapamiento: un producto repetido son dos compras', () {
      final merged = ReceiptSpatialParser.mergePhotos([
        [_row('LECHE 100,00', 1)],
        [_row('LECHE 100,00', 2), _row('TOTAL 200,00', 2, 2)],
      ]);
      expect(_texts(merged), ['LECHE 100,00', 'LECHE 100,00', 'TOTAL 200,00']);
    });

    test('busca el solapamiento más largo posible (hasta 6 filas)', () {
      final tail = [for (var i = 1; i <= 7; i++) _row('R$i', 1, i)];
      final merged = ReceiptSpatialParser.mergePhotos([
        tail,
        [for (var i = 2; i <= 7; i++) _row('R$i', 2, i - 1), _row('FIN', 2, 7)],
      ]);
      expect(_texts(merged), ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'FIN']);
    });

    test('fotos vacías se saltean; sin fotos, sin filas; una sola foto queda igual', () {
      final one = [_row('A', 1)];
      expect(ReceiptSpatialParser.mergePhotos([]), isEmpty);
      expect(ReceiptSpatialParser.mergePhotos([one]), same(one));
      expect(_texts(ReceiptSpatialParser.mergePhotos([one, [], [_row('B', 3)]])), ['A', 'B']);
    });
  });

  test('sin fotos: ticket vacío', () {
    final r = ReceiptSpatialParser.parseMultipleRecognizedTexts([]);
    expect([r.items, r.totales.totalPagado], [isEmpty, 0]);
  });
}
