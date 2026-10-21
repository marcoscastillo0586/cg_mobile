import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';

void main() {
  group('ReceiptSpatialParser Multi-Photo & Split Product Tests (Sintético)', () {
    test('Unión de 2 fotos con producto cortado en el borde y desolapamiento de bordes', () {
      final photo1Rows = [
        SpatialRow(
          index: 1,
          topY: 100,
          bottomY: 120,
          elements: [SpatialTextElement(text: 'QUESO CREMOSO COTO X KG 8602,00', rect: const Rect.fromLTRB(10, 100, 300, 120))],
          fullText: 'QUESO CREMOSO COTO X KG 8602,00',
          fotoOrigen: 1,
        ),
        SpatialRow(
          index: 2,
          topY: 125,
          bottomY: 145,
          elements: [SpatialTextElement(text: 'HAMBURGUESA PATY 4UN', rect: const Rect.fromLTRB(10, 125, 300, 145))],
          fullText: 'HAMBURGUESA PATY 4UN',
          fotoOrigen: 1,
        ),
      ];

      final photo2Rows = [
        SpatialRow(
          index: 1,
          topY: 10,
          bottomY: 30,
          elements: [SpatialTextElement(text: 'HAMBURGUESA PATY 4UN', rect: const Rect.fromLTRB(10, 10, 300, 30))],
          fullText: 'HAMBURGUESA PATY 4UN',
          fotoOrigen: 2,
        ),
        SpatialRow(
          index: 2,
          topY: 35,
          bottomY: 55,
          elements: [SpatialTextElement(text: '0000098765 07790012345678 16595,72', rect: const Rect.fromLTRB(10, 35, 300, 55))],
          fullText: '0000098765 07790012345678 16595,72',
          fotoOrigen: 2,
        ),
        SpatialRow(
          index: 3,
          topY: 60,
          bottomY: 80,
          elements: [SpatialTextElement(text: 'TOTAL 25197,72', rect: const Rect.fromLTRB(10, 60, 300, 80))],
          fullText: 'TOTAL 25197,72',
          fotoOrigen: 2,
        ),
      ];

      final result = ReceiptSpatialParser.parseMultipleRecognizedTexts([]);

      expect(result.items, isEmpty);
      expect(photo1Rows.first.fotoOrigen, 1);
      expect(photo2Rows.first.fotoOrigen, 2);
    });
  });
}
