import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../l10n/l10n.dart';

/// Ajustes locales del dispositivo. Se conservan al cerrar sesión.
/// El servidor no se configura acá: se fija al compilar (`API_BASE_URL`).
class SettingsState {
  final ThemeMode themeMode;
  final String language; // 'es', 'en'
  final String defaultCurrency; // 'ARS', 'USD', 'EUR', 'PEN'
  final bool isFirstLaunch;

  const SettingsState({
    required this.themeMode,
    this.language = 'es',
    this.defaultCurrency = 'ARS',
    this.isFirstLaunch = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? language,
    String? defaultCurrency,
    bool? isFirstLaunch,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return SettingsNotifier(storageService);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SecureStorageService _storageService;

  /// La API solo maneja ARS y USD. Nombre visible: [currencyLabel].
  static const List<String> monedasDisponibles = ['ARS', 'USD'];

  static String currencyLabel(String code, AppLocalizations l) => switch (code) {
        'USD' => l.currencyUsd,
        _ => l.currencyArs,
      };

  static const Map<String, String> idiomasDisponibles = {
    'es': 'Español',
    'en': 'English',
  };

  SettingsNotifier(this._storageService)
      : super(const SettingsState(themeMode: ThemeMode.system)) {
    inicializar();
  }

  Future<void> inicializar() async {
    try {
      final savedTheme = await _storageService.getThemeMode();
      if (savedTheme != null) {
        if (savedTheme == 'light') {
          state = state.copyWith(themeMode: ThemeMode.light);
        } else if (savedTheme == 'dark') {
          state = state.copyWith(themeMode: ThemeMode.dark);
        } else {
          state = state.copyWith(themeMode: ThemeMode.system);
        }
      }

      final savedLang = await _storageService.getLanguage();
      if (savedLang != null && savedLang.isNotEmpty) {
        state = state.copyWith(language: savedLang);
      }

      final savedCurrency = await _storageService.getDefaultCurrency();
      if (savedCurrency != null && savedCurrency.isNotEmpty) {
        // Una moneda guardada que ya no se ofrece (EUR, PEN…) vuelve a ARS.
        state = state.copyWith(defaultCurrency: monedasDisponibles.contains(savedCurrency) ? savedCurrency : 'ARS');
      }

      final firstDone = await _storageService.isFirstLaunchDone();
      state = state.copyWith(isFirstLaunch: !firstDone);
    } catch (e) {
      // Ajustes ilegibles: se usan los valores por defecto y se registra el motivo.
      debugPrint('[AJUSTES] No se pudieron leer los ajustes guardados: $e');
    }
  }

  Future<void> cambiarIdioma(String lang) async {
    state = state.copyWith(language: lang);
    await _storageService.saveLanguage(lang);
  }

  Future<void> cambiarMonedaDefault(String currency) async {
    state = state.copyWith(defaultCurrency: currency);
    await _storageService.saveDefaultCurrency(currency);
  }

  Future<void> guardarConfiguracionInicial({
    required String moneda,
    required String idioma,
  }) async {
    state = state.copyWith(
      defaultCurrency: moneda,
      language: idioma,
      isFirstLaunch: false,
    );
    await _storageService.saveDefaultCurrency(moneda);
    await _storageService.saveLanguage(idioma);
    await _storageService.saveFirstLaunchDone();
  }

  Future<void> cambiarThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _storageService.saveThemeMode(modeStr);
  }
}
