import '../errors/exceptions.dart';

/// Monedas que maneja la API (`currencySchema` de @cg/shared): solo ARS y USD.
enum Currency {
  ars('ARS', r'$'),
  usd('USD', r'US$');

  final String code;
  final String symbol;
  const Currency(this.code, this.symbol);

  static Currency parse(Object? value) {
    for (final c in Currency.values) {
      if (c.code == value) return c;
    }
    throw ServerException('Moneda desconocida: $value', null, 'UNEXPECTED_RESPONSE');
  }
}

/// Importes en centavos (enteros), como los envía la API. Nunca se usa double.
class Money {
  Money._();

  /// "$ 1.234,56", "-US$ 10,00" o "$ ••••••" si [hidden].
  static String format(int cents, {Currency currency = Currency.ars, bool hidden = false, bool decimals = true}) {
    if (hidden) return '${currency.symbol} ••••••';
    final negative = cents < 0;
    final abs = cents.abs();
    final units = abs ~/ 100;
    final fraction = abs % 100;
    final grouped = _group(units);
    final text = decimals ? '$grouped,${fraction.toString().padLeft(2, '0')}' : grouped;
    return '${negative ? '-' : ''}${currency.symbol} $text';
  }

  /// Porcentaje con 2 decimales como lo devuelve la API (p. ej. 75.5 → "75,50 %").
  static String percent(num value) {
    final hundredths = (value * 100).round();
    final negative = hundredths < 0;
    final abs = hundredths.abs();
    return '${negative ? '-' : ''}${_group(abs ~/ 100)},${(abs % 100).toString().padLeft(2, '0')} %';
  }

  /// Exige un entero (centavos). Un número con decimales es un error de contrato.
  static int centsFrom(Object? value, String field) {
    if (value is int) return value;
    throw ServerException('Importe inválido en "$field": $value', null, 'UNEXPECTED_RESPONSE');
  }

  /// Lo que escribe el usuario → centavos, sin pasar por double. Acepta "1234", "1234,5",
  /// "1.234,56" y "1234.56". Devuelve null si está vacío, no es un número, tiene más de 2
  /// decimales o es negativo.
  static int? parseInput(String text) {
    final m = _input.firstMatch(text.trim().replaceAll(' ', ''));
    if (m == null) return null;
    final group = m.group(2), decimal = m.group(3);
    if (group != null && group == decimal) return null; // "1.234.56": ambiguo
    final units = m.group(1)!.replaceAll(RegExp(r'[.,]'), '');
    if (units.length > 13) return null;
    final frac = (m.group(4) ?? '').padRight(2, '0');
    return int.parse(units) * 100 + int.parse(frac);
  }

  /// Entero con miles agrupados de a 3 ("1.234.567") o sin agrupar, y hasta 2 decimales.
  static final _input = RegExp(r'^(\d{1,3}([.,])\d{3}(?:\2\d{3})*|\d+)(?:([.,])(\d{1,2}))?$');

  /// Centavos → decimal con punto para la API ("1234.56"); el signo lo pone el servidor.
  static String toApiDecimal(int cents) {
    final abs = cents.abs();
    return '${cents < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  static String _group(int units) {
    final digits = units.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
