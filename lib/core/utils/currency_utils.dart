import 'package:intl/intl.dart';

class AppCurrencyUtils {
  static final NumberFormat _numFormatDecimal = NumberFormat('#,##0.00', 'es_AR');
  static final NumberFormat _numFormatInteger = NumberFormat('#,##0', 'es_AR');

  /// Formatea un monto anteponiendo de forma estricta el símbolo: "$ 1.200,00" o "US$ 500,00"
  static String format(
    double amount, {
    String symbol = '\$',
    bool showDecimals = true,
    bool ocultar = false,
  }) {
    final sym = symbol.trim();
    if (ocultar) {
      return '$sym ••••••';
    }

    final absVal = amount.abs();
    final formattedNum = showDecimals
        ? _numFormatDecimal.format(absVal)
        : _numFormatInteger.format(absVal);

    final sign = amount < 0 ? '-' : '';
    return '$sign$sym $formattedNum';
  }
}
