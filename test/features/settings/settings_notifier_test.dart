import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/constants/api_endpoints.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/settings/presentation/providers/settings_provider.dart';

class FakeSecureStorageService implements SecureStorageService {
  String? savedBaseUrl;
  String? savedTheme;

  @override
  Future<void> saveBaseUrl(String url) async => savedBaseUrl = url;

  @override
  Future<String?> getBaseUrl() async => savedBaseUrl;

  @override
  Future<void> deleteBaseUrl() async => savedBaseUrl = null;

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
    test('cambiarBaseUrl normaliza y persiste la URL del servidor', () async {
      final fakeStorage = FakeSecureStorageService();
      final dioClient = DioClient(fakeStorage);
      final notifier = SettingsNotifier(fakeStorage, dioClient);
      await notifier.inicializar();

      await notifier.cambiarBaseUrl('http://192.168.0.100/gastos2.0/');

      expect(notifier.state.baseUrl, 'http://192.168.0.100/gastos2.0');
      expect(fakeStorage.savedBaseUrl, 'http://192.168.0.100/gastos2.0');
      expect(ApiEndpoints.baseUrl, 'http://192.168.0.100/gastos2.0');
    });

    test('cambiarThemeMode persiste y actualiza ThemeMode', () async {
      final fakeStorage = FakeSecureStorageService();
      final dioClient = DioClient(fakeStorage);
      final notifier = SettingsNotifier(fakeStorage, dioClient);
      await notifier.inicializar();

      await notifier.cambiarThemeMode(ThemeMode.dark);

      expect(notifier.state.themeMode, ThemeMode.dark);
      expect(fakeStorage.savedTheme, 'dark');

      await notifier.cambiarThemeMode(ThemeMode.light);

      expect(notifier.state.themeMode, ThemeMode.light);
      expect(fakeStorage.savedTheme, 'light');
    });

    test('restablecerBaseUrlPredeterminada resetea a IP predeterminada', () async {
      final fakeStorage = FakeSecureStorageService();
      final dioClient = DioClient(fakeStorage);
      final notifier = SettingsNotifier(fakeStorage, dioClient);
      await notifier.inicializar();


      await notifier.cambiarBaseUrl('http://10.0.0.15/test');
      expect(notifier.state.baseUrl, 'http://10.0.0.15/test');

      await notifier.restablecerBaseUrlPredeterminada();
      expect(notifier.state.baseUrl, 'http://192.168.0.50/gastos2.0');
      expect(fakeStorage.savedBaseUrl, isNull);
    });
  });
}
