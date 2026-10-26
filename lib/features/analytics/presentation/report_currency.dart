import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money/money.dart';
import '../../settings/presentation/providers/settings_provider.dart';

/// Moneda de los reportes: la principal (el servidor y LocalReports cuentan solo esa moneda).
Currency reportCurrency(BuildContext context) =>
    Currency.parse(ProviderScope.containerOf(context, listen: false).read(settingsProvider).defaultCurrency);
