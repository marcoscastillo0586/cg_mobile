import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';

void main() {
  group('ReceiptSpatialParser Real Fixtures Tests (extractor v4)', () {
    test('SpatialTextElement computes centerY and height correctly', () {
      final elem = SpatialTextElement(
        text: 'LECHE ENTERA COTO',
        rect: const Rect.fromLTRB(10, 100, 200, 120),
      );

      expect(elem.centerY, 110.0);
      expect(elem.height, 20.0);
    });

    test('SpatialRow formats row text correctly', () {
      final elem1 = SpatialTextElement(
        text: 'LECHE ENTERA COTO',
        rect: const Rect.fromLTRB(10, 100, 200, 120),
      );
      final elem2 = SpatialTextElement(
        text: '1250,50',
        rect: const Rect.fromLTRB(300, 102, 380, 122),
      );

      final row = SpatialRow(
        index: 1,
        topY: 100,
        bottomY: 122,
        elements: [elem1, elem2],
        fullText: 'LECHE ENTERA COTO 1250,50',
      );

      expect(row.index, 1);
      expect(row.fullText, contains('LECHE ENTERA COTO'));
      expect(row.fullText, contains('1250,50'));
    });
  });
}
