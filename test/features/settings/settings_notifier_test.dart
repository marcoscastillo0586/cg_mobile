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

  @override
  Future<String?> getDefaultCurrency() async => null;

  @override
  Future<bool> isFirstLaunchDone() async => true;

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

  });
}
