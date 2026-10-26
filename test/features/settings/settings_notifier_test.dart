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

  });
}
