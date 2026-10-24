import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Textos traducidos de la pantalla actual (`lib/l10n/app_*.arb`; plantilla: español).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Nombre del mes (1-12) en el idioma de la app, con mayúscula inicial ("Enero", "Ene").
  String monthName(int month, {bool short = false}) {
    final s = DateFormat(short ? 'MMM' : 'MMMM', l10n.localeName).format(DateTime(2000, month)).replaceAll('.', '');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
}
