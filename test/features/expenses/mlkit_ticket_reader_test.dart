// Armado del resultado de la lectura con ML Kit a partir de RecognizedText construidos a mano (el OCR real sólo
// corre en el celular).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/expenses/data/services/mlkit_ticket_reader.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

TextLine _line(String text, double left, double top) => TextLine(
      text: text,
      elements: const [],
      boundingBox: Rect.fromLTWH(left, top, 200, 20),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

RecognizedText _photo(String raw, List<TextLine> lines) => RecognizedText(text: raw, blocks: [
      TextBlock(text: raw, lines: lines, boundingBox: Rect.zero, recognizedLanguages: const [], cornerPoints: const []),
    ]);

void main() {
  test('cada foto por separado: se juntan los renglones y vale el último total leído; registro con las líneas crudas', () {
    final r = MlKitTicketReader.resultFrom([
      _photo('foto 1', [_line('PAN FRANCES', 10, 60), _line('0000015889 07790040008175', 10, 100), _line('1500,00', 320, 101), _line('TOTAL', 10, 200), _line('1500,00', 320, 201)]),
      _photo('foto 2', [_line('LECHE 900,00', 10, 60), _line('TOTAL', 10, 100), _line('2400,00', 320, 100)]),
      _photo('foto 3', [_line('GRACIAS', 10, 10)]),
    ], ['a.jpg', 'b.jpg', 'c.jpg'], StringBuffer());
    expect([for (final i in r.items) (i.nombre, i.precioCents)], [('PAN FRANCES', 150000), ('LECHE', 90000)]);
    expect(r.totalDetectadoCents, 240000);
    expect(r.readerName, 'mlkit_spatial_parser');
    expect(r.rawTexts, ['foto 1', 'foto 2', 'foto 3']);
    expect(r.imagePaths, ['a.jpg', 'b.jpg', 'c.jpg']);
    expect(r.diagnosticLog, contains('Foto #2 - Líneas raw detectadas por Google ML Kit (Total: 3):'));
    expect(r.diagnosticLog, contains('Línea #01 [L: 10, T: 60, R: 210, B: 80]: "LECHE 900,00"'));
  });

  test('sin fotos: sin renglones ni total', () {
    final r = MlKitTicketReader.resultFrom([], const [], StringBuffer());
    expect(r.items, isEmpty);
    expect(r.totalDetectadoCents, isNull);
    expect(r.rawTexts, isEmpty);
  });
}
