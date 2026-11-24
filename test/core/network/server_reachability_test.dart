// Qué cuenta como "sin conexión con el servidor": red caída o 5xx del propio servidor; no las fallas de la lectura
// de tickets, que el servidor sí informa.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/server_reachability.dart';

void main() {
  test('error de red y 5xx / TEMPORARY_ERROR del servidor: sin conexión', () {
    expect(ServerReachability.isOfflineError(const NetworkException()), isTrue);
    expect(ServerReachability.isOfflineError(const ServerException('x', 503, 'INTERNAL_ERROR')), isTrue);
    expect(ServerReachability.isOfflineError(const ServerException('x', 504, 'UNEXPECTED_RESPONSE')), isTrue);
    expect(ServerReachability.isOfflineError(const ServerException('x', 429, 'TEMPORARY_ERROR')), isTrue);
  });

  test('rechazos de negocio y errores que no son del servidor: con conexión', () {
    expect(ServerReachability.isOfflineError(const ServerException('x', 409, 'INSUFFICIENT_FUNDS')), isFalse);
    expect(ServerReachability.isOfflineError(const ServerException('x', null, null)), isFalse);
    expect(ServerReachability.isOfflineError(StateError('x')), isFalse);
  });

  test('fallas de la lectura de tickets (Gemini saturado, sin cupo, tiempo agotado…): el servidor respondió', () {
    for (final (status, code) in [(503, 'GEMINI_OVERLOADED'), (429, 'GEMINI_QUOTA'), (504, 'GEMINI_TIMEOUT'), (502, 'GEMINI_INVALID'), (503, 'GEMINI_UNAVAILABLE'), (503, 'GEMINI_NOT_CONFIGURED')]) {
      expect(ServerReachability.isOfflineError(ServerException('x', status, code)), isFalse, reason: code);
    }
  });
}
