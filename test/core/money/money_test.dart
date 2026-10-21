import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/money/money.dart';

void main() {
  test('formatea centavos con miles y 2 decimales, sin double', () {
    expect(Money.format(0), r'$ 0,00');
    expect(Money.format(5), r'$ 0,05');
    expect(Money.format(123456789), r'$ 1.234.567,89');
    expect(Money.format(-150000), r'-$ 1.500,00');
    expect(Money.format(100000, currency: Currency.usd), r'US$ 1.000,00');
    expect(Money.format(999, hidden: true), r'$ ••••••');
    expect(Money.format(123456, decimals: false), r'$ 1.234');
  });

  test('valores grandes no pierden precisión (supera Int32 y la precisión de double en 2 decimales)', () {
    expect(Money.format(900719925474099), r'$ 9.007.199.254.740,99');
  });

  test('porcentaje con 2 decimales', () {
    expect(Money.percent(75.5), '75,50 %');
    expect(Money.percent(100), '100,00 %');
    expect(Money.percent(-12.34), '-12,34 %');
  });

  test('moneda: solo ARS y USD; otra es error de contrato', () {
    expect(Currency.parse('ARS'), Currency.ars);
    expect(Currency.parse('USD'), Currency.usd);
    expect(() => Currency.parse('EUR'), throwsA(isA<ServerException>()));
  });

  test('centsFrom exige enteros', () {
    expect(Money.centsFrom(1500, 'x'), 1500);
    expect(() => Money.centsFrom(15.5, 'x'), throwsA(isA<ServerException>()));
    expect(() => Money.centsFrom(null, 'x'), throwsA(isA<ServerException>()));
  });
}
