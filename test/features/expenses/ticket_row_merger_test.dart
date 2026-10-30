// Ticket largo R3: unión de las filas de partes consecutivas sin repetir la superposición.
// Filas SINTÉTICAS con la forma de un ticket de Coto (el OCR real solo corre en el celular).
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
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
  const merger = TicketRowMerger();

  test('une sin repetir la superposición, tolerando errores de OCR y filas cortadas en los bordes', () {
    final a = _part(1, [
      'COTO C.I.C.S.A.',
      'SUC 123',
      'KRACHITOS',
      '7794520868969 21.00 2.520,00',
      'GALLETITAS OREO',
      '7622300489434 21.00 1.800,00',
      'QUESO CREM', // última fila de A cortada por el borde
    ]);
    final b = _part(2, [
      'HITOS', // primera fila de B cortada por el borde
      '7794520868969 21.0O 2.520,00', // OCR: "O" en lugar de "0"
      'GALLETITAS 0REO',
      '7622300489434 21.00 1.800,00',
      'QUESO CREMOSO',
      '7790123456789 21.00 3.000,00',
      'KRACHITOS',
      '7794520869027 21.00 2.520,00',
      'TOTAL 9.840,00',
    ]);

    final r = merger.merge([a, b]);

    expect(r.failed, isNull);
    expect(r.joins[1].overlapRows, 3);
    expect(r.rows.map((x) => x.fullText), [
      'COTO C.I.C.S.A.',
      'SUC 123',
      'KRACHITOS',
      '7794520868969 21.00 2.520,00', // texto ORIGINAL de A (no la versión con error de B)
      'GALLETITAS OREO',
      '7622300489434 21.00 1.800,00',
      'QUESO CREMOSO', // la fila cortada de A se reemplaza por la completa de B
      '7790123456789 21.00 3.000,00',
      'KRACHITOS', // mismo nombre, otro código: NO es un duplicado
      '7794520869027 21.00 2.520,00',
      'TOTAL 9.840,00',
    ]);
    expect(r.rows.map((x) => x.index), List.generate(11, (i) => i + 1));
    expect(r.rows.last.fotoOrigen, 2);
  });

  test('sin superposición válida no se une y se informa la parte a rehacer', () {
    final a = _part(1, ['LECHE', '7790001 21.00 1.500,00', 'PAN', '7790002 21.00 900,00']);
    final b = _part(2, ['ARROZ', '7790003 21.00 1.100,00', 'TOTAL 3.500,00']);

    final r = merger.merge([a, b]);

    expect(r.failed?.part, 2);
    expect(r.failed?.status, TicketJoinStatus.noOverlap);
    expect(r.rows.map((x) => x.fullText), a.map((x) => x.fullText), reason: 'no se unió nada de la parte 2');
  });

  test('una fila aislada que coincide no es superposición (mínimo 3 filas consecutivas)', () {
    final a = _part(1, ['LECHE', '7790001 21.00 1.500,00', 'KRACHITOS']);
    final b = _part(2, ['KRACHITOS', '7794520869027 21.00 2.520,00', 'TOTAL 4.020,00']);

    expect(merger.merge([a, b]).failed?.status, TicketJoinStatus.noOverlap);
  });

  test('dos superposiciones igual de buenas: ambigua, no se adivina', () {
    final a = _part(1, ['COTO', 'R', 'R', 'R', 'R']);
    final b = _part(2, ['R', 'R', 'R', 'TOTAL 1,00']);

    final r = merger.merge([a, b]);

    expect(r.failed?.part, 2);
    expect(r.failed?.status, TicketJoinStatus.ambiguous);
  });

  test('tres partes: cada una se encadena con lo ya unido', () {
    final a = _part(1, ['COTO', 'A1', 'A2', 'A3', 'A4']);
    final b = _part(2, ['A2', 'A3', 'A4', 'B1', 'B2', 'B3']);
    final c = _part(3, ['B1', 'B2', 'B3', 'TOTAL 10,00']);

    final r = merger.merge([a, b, c]);

    expect(r.failed, isNull);
    expect(r.rows.map((x) => x.fullText), ['COTO', 'A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'TOTAL 10,00']);
  });

  test('normalización solo para comparar y similitud de Levenshtein', () {
    expect(TicketRowMerger.normalize('  galletitas   oreo '), 'GALLETITAS OREO');
    expect(TicketRowMerger.similarity('GALLETITAS OREO', 'GALLETITAS OREO'), 1);
    expect(TicketRowMerger.similarity('GALLETITAS OREO', 'GALLETITAS 0REO'), closeTo(14 / 15, 1e-9));
  });
}
