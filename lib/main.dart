import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/session_scope.dart';
import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'routes/app_router.dart';
import 'core/constants/app_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En release no se escribe nada en logcat (errores del servidor, filas de tickets, montos):
  // los diagnósticos con debugPrint, propios o de paquetes, son solo para debug.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  runApp(
    const SessionScope(child: GastosMobileApp()),
  );
}

class GastosMobileApp extends ConsumerWidget {
  const GastosMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: Locale(settings.language),
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es'),
        Locale('en', 'US'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
