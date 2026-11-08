// Lectura por foto en el servidor (POST /tickets/read-images): la respuesta se convierte en el mismo
// resultado que la lectura con ML Kit (misma revisión, mismas validaciones y mismo guardado).
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/expenses/data/tickets_repository.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/ticket_parse_result.dart';

void main() {
  final body = {
    'reader': 'ollama',
    'merchant': 'SUPER DIA',
    'receiptDate': '07/10/2026',
    'receiptNumber': '0001-00012345',
    'items': [
      {'description': 'LECHE ENTERA', 'code': '7790001', 'quantity': 2, 'unitPriceCents': 125000, 'amountCents': 250000, 'discountCents': 50000, 'netCents': 200000},
      {'description': 'PAN', 'code': null, 'quantity': null, 'unitPriceCents': null, 'amountCents': 90050, 'discountCents': 0, 'netCents': 90050},
    ],
    'subtotalCents': 340050,
    'discountCents': 50000,
    'totalPrintedCents': 290050,
  };

  test('renglones con su importe neto y total impreso, sin QR (se guarda como la lectura del celular)', () {
    final r = TicketsRepository.parseImageTicket(body, ['a.jpg', 'b.jpg']);
    expect(r.readerName, 'ollama');
    expect(r.items, const [
      ParsedTicketItem(nombre: 'LECHE ENTERA', precioCents: 200000),
      ParsedTicketItem(nombre: 'PAN', precioCents: 90050),
    ]);
    expect(r.totalDetectadoCents, 290050);
    expect(r.imagePaths, ['a.jpg', 'b.jpg']);
    expect(r.qr, isNull);
    expect(r.tieneDiferenciaTotal, false);
  });

  test('sin total impreso: la verificación informa que no se leyó el total', () {
    final r = TicketsRepository.parseImageTicket({...body, 'totalPrintedCents': null}, const []);
    expect(r.totalDetectadoCents, isNull);
    expect(r.tieneDiferenciaTotal, false);
  });

  test('la suma que no coincide con el total impreso se marca igual que con ML Kit', () {
    final r = TicketsRepository.parseImageTicket({...body, 'totalPrintedCents': 100000}, const []);
    expect(r.tieneDiferenciaTotal, true);
  });

  test('respuesta inesperada → ServerException', () {
    expect(() => TicketsRepository.parseImageTicket('x', const []), throwsA(isA<ServerException>()));
    expect(() => TicketsRepository.parseImageTicket({'items': 'x'}, const []), throwsA(isA<ServerException>()));
    expect(
      () => TicketsRepository.parseImageTicket({
        'items': [
          {'description': 'X', 'netCents': 12.5},
        ],
      }, const []),
      throwsA(isA<ServerException>()),
    );
  });

  test('el tiempo de esta llamada supera el de Ollama en el servidor (180 s) con margen', () {
    expect(TicketsRepository.readImagesTimeout > const Duration(milliseconds: 180000), true);
    expect(TicketsRepository.maxImages, 5);
  });
}
