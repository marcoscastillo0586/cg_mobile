import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coto Ticket HTML Parser Real Fixture Verification Tests', () {
    test('Verifica existencia y tamaño del archivo coto_ticket_fixture.html', () async {
      final file = File('test/fixtures/coto_ticket_fixture.html');
      expect(await file.exists(), isTrue);

      final contents = await file.readAsString();
      expect(contents, contains('SUC131 COTO CICSA'));
      expect(contents, contains('30-54808315-6'));
      expect(contents, contains('131-09962018'));
      expect(contents, contains('Subtotal sin descuentos'));
      expect(contents, contains('169.597,97'));
      expect(contents, contains('24.754,57'));
      expect(contents, contains('144.843,41'));
    });
  });
}
