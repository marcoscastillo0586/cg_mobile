// Ticket largo R2: filas de UNA parte reconstruidas por posición vertical, con texto reconocido SINTÉTICO
// (el OCR real de ML Kit solo corre en el celular).
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:gastos_mobile/features/expenses/data/services/receipt_spatial_parser.dart';

/// Un bloque con una línea en la caja indicada (como lo entrega ML Kit).
TextBlock _block(String text, Rect box) => TextBlock(
      text: text,
      lines: [
        TextLine(text: text, elements: const [], boundingBox: box, recognizedLanguages: const [], cornerPoints: const [], confidence: null, angle: null),
      ],
      boundingBox: box,
      recognizedLanguages: const [],
      cornerPoints: const [],
    );

void main() {
  test('nombre y precio en bloques separados quedan en la misma fila, de izquierda a derecha', () {
    // El precio viene antes en la lista (otro bloque, a la derecha) y con una leve diferencia de altura.
    final text = RecognizedText(text: '', blocks: [
      _block('7794520868969 21.00', const Rect.fromLTRB(20, 140, 400, 160)),
      _block('2.520,00', const Rect.fromLTRB(600, 102, 720, 122)),
      _block('KRACHITOS', const Rect.fromLTRB(20, 100, 300, 120)),
    ]);

    final rows = ReceiptSpatialParser.filasDeFoto(text, 2);

    expect(rows.map((r) => r.fullText), ['KRACHITOS 2.520,00', '7794520868969 21.00']);
    expect(rows.every((r) => r.fotoOrigen == 2), isTrue, reason: 'cada fila recuerda de qué parte viene');
  });

  test('una parte sin texto no tiene filas', () {
    expect(ReceiptSpatialParser.filasDeFoto(RecognizedText(text: '', blocks: const []), 1), isEmpty);
  });
}
