import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  /// Formatea una fecha a 'dd/MM/yyyy'
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _dateFormat.format(date);
  }

  /// Formatea una fecha con hora a 'dd/MM/yyyy HH:mm'
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return _dateTimeFormat.format(date);
  }

  /// Formatea una cadena ISO o 'yyyy-MM-dd' a 'dd/MM/yyyy'
  static String formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    // Una fecha que no se puede leer (p. ej. '0000-00-00 00:00:00' heredada) se muestra tal cual.
    final parsed = DateTime.tryParse(dateStr);
    return parsed == null ? dateStr : _dateFormat.format(parsed);
  }

  /// Formatea una cadena ISO a 'dd/MM/yyyy HH:mm'
  static String formatDateTimeString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    // Una fecha que no se puede leer (p. ej. '0000-00-00 00:00:00' heredada) se muestra tal cual.
    final parsed = DateTime.tryParse(dateStr);
    return parsed == null ? dateStr : _dateTimeFormat.format(parsed);
  }

  /// Convierte una fecha a string para la API ('yyyy-MM-dd')
  static String toApiDate(DateTime date) {
    return _apiDateFormat.format(date);
  }
}

extension DateTimeFormatting on DateTime {
  String toAppDate() => AppDateUtils.formatDate(this);
  String toAppDateTime() => AppDateUtils.formatDateTime(this);
  String toApiDate() => AppDateUtils.toApiDate(this);
}
