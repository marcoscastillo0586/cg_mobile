import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/settings/presentation/providers/settings_provider.dart';

class FakeSecureStorageService implements SecureStorageService {
  String? savedTheme;

  @override
  Future<void> saveThemeMode(String mode) async => savedTheme = mode;

  @override
  Future<String?> getThemeMode() async => savedTheme;

  // SettingsNotifier.inicializar() también lee estos valores; el fake no los tenía.
  @override
  Future<String?> getLanguage() async => null;

  /// Moneda y primer ingreso por cuenta (cuenta 7: dólares y ya hizo el primer ingreso).
  @override
  Future<String?> getDefaultCurrency(int userId) async => userId == 7 ? 'USD' : null;

  @override
  Future<bool> isFirstLaunchDone(int userId) async => userId == 7;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SettingsNotifier Tests', () {

    test('cambiarThemeMode persiste y actualiza ThemeMode', () async {
      final fakeStorage = FakeSecureStorageService();
      final notifier = SettingsNotifier(fakeStorage);
      await notifier.inicializar();

      await notifier.cambiarThemeMode(ThemeMode.dark);

      expect(notifier.state.themeMode, ThemeMode.dark);
      expect(fakeStorage.savedTheme, 'dark');

      await notifier.cambiarThemeMode(ThemeMode.light);

      expect(notifier.state.themeMode, ThemeMode.light);
      expect(fakeStorage.savedTheme, 'light');
    });

    test('cargarCuenta: moneda y primer ingreso son de cada cuenta', () async {
      final notifier = SettingsNotifier(FakeSecureStorageService());
      await notifier.listo;

      await notifier.cargarCuenta(7);
      expect((notifier.state.defaultCurrency, notifier.state.isFirstLaunch), ('USD', false));

      // Otra cuenta del celular, sin nada guardado: pesos y su propio primer ingreso.
      await notifier.cargarCuenta(8);
      expect((notifier.state.defaultCurrency, notifier.state.isFirstLaunch), ('ARS', true));
    });

    test('tema guardado: claro, oscuro; otro o nada, el del sistema', () {
      expect(SettingsNotifier.themeFrom('light'), ThemeMode.light);
      expect(SettingsNotifier.themeFrom('dark'), ThemeMode.dark);
      expect(SettingsNotifier.themeFrom('system'), ThemeMode.system);
      expect(SettingsNotifier.themeFrom(null), ThemeMode.system);
    });

    test('al iniciar lee tema e idioma guardados; idioma vacío deja el de por defecto', () async {
      final storage = _Guardado(theme: 'dark', lang: 'en');
      final n = SettingsNotifier(storage);
      await n.listo;
      expect((n.state.themeMode, n.state.language), (ThemeMode.dark, 'en'));
      final vacio = SettingsNotifier(_Guardado(theme: null, lang: ''));
      await vacio.listo;
      expect((vacio.state.themeMode, vacio.state.language), (ThemeMode.system, 'es'));
    });

    test('ajustes ilegibles: quedan los de por defecto', () async {
      final n = SettingsNotifier(_Guardado(theme: 'dark', lang: 'en', falla: true));
      await n.listo;
      expect((n.state.themeMode, n.state.language), (ThemeMode.system, 'es'));
    });

  });
}

class _Guardado implements SecureStorageService {
  final String? theme;
  final String? lang;
  final bool falla;
  _Guardado({required this.theme, required this.lang, this.falla = false});

  @override
  Future<String?> getThemeMode() async => falla ? throw StateError('ilegible') : theme;
  @override
  Future<String?> getLanguage() async => lang;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
