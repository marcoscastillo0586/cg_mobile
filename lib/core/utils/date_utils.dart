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
    try {
      final parsed = DateTime.parse(dateStr);
      return _dateFormat.format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  /// Formatea una cadena ISO a 'dd/MM/yyyy HH:mm'
  static String formatDateTimeString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr);
      return _dateTimeFormat.format(parsed);
    } catch (_) {
      return dateStr;
    }
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
