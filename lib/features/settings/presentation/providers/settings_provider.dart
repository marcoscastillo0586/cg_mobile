import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class SettingsState {
  final String baseUrl;
  final ThemeMode themeMode;
  final String language; // 'es', 'en'
  final String defaultCurrency; // 'ARS', 'USD', 'EUR', 'PEN'
  final bool isFirstLaunch;
  final bool isTestingConnection;
  final String? connectionStatus;
  final bool? connectionOk;

  const SettingsState({
    required this.baseUrl,
    required this.themeMode,
    this.language = 'es',
    this.defaultCurrency = 'ARS',
    this.isFirstLaunch = false,
    this.isTestingConnection = false,
    this.connectionStatus,
    this.connectionOk,
  });

  SettingsState copyWith({
    String? baseUrl,
    ThemeMode? themeMode,
    String? language,
    String? defaultCurrency,
    bool? isFirstLaunch,
    bool? isTestingConnection,
    String? connectionStatus,
    bool? connectionOk,
    bool clearStatus = false,
  }) {
    return SettingsState(
      baseUrl: baseUrl ?? this.baseUrl,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionStatus: clearStatus ? null : (connectionStatus ?? this.connectionStatus),
      connectionOk: clearStatus ? null : (connectionOk ?? this.connectionOk),
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  final dioClient = ref.watch(dioClientProvider);
  return SettingsNotifier(storageService, dioClient);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SecureStorageService _storageService;
  final DioClient _dioClient;

  static const List<String> presetUrls = [
    'http://192.168.0.50/gastos2.0',
    'http://10.0.2.2/gastos2.0',
    'http://localhost/gastos2.0',
  ];

  static const Map<String, String> monedasDisponibles = {
    'ARS': 'Pesos Argentinos (ARS \$)',
    'USD': 'Dólares (USD \$)',
    'EUR': 'Euros (EUR €)',
    'PEN': 'Soles Peruanos (PEN S/)',
    'CLP': 'Pesos Chilenos (CLP \$)',
    'MXN': 'Pesos Mexicanos (MXN \$)',
    'BRL': 'Reales (BRL R\$)',
  };

  static const Map<String, String> idiomasDisponibles = {
    'es': 'Español',
    'en': 'English',
  };

  SettingsNotifier(this._storageService, this._dioClient)
      : super(SettingsState(
          baseUrl: ApiEndpoints.baseUrl,
          themeMode: ThemeMode.system,
        )) {
    inicializar();
  }

  Future<void> inicializar() async {
    final savedBaseUrl = await _storageService.getBaseUrl();
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      ApiEndpoints.baseUrl = savedBaseUrl.trim();
      _dioClient.updateBaseUrl(ApiEndpoints.baseUrl);
      state = state.copyWith(baseUrl: ApiEndpoints.baseUrl);
    }

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
      state = state.copyWith(defaultCurrency: savedCurrency);
    }

    final firstDone = await _storageService.isFirstLaunchDone();
    state = state.copyWith(isFirstLaunch: !firstDone);
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

  Future<void> cambiarBaseUrl(String newUrl) async {
    var cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    ApiEndpoints.baseUrl = cleanUrl;
    _dioClient.updateBaseUrl(cleanUrl);
    await _storageService.saveBaseUrl(cleanUrl);

    state = state.copyWith(
      baseUrl: cleanUrl,
      clearStatus: true,
    );
  }

  Future<void> restablecerBaseUrlPredeterminada() async {
    await _storageService.deleteBaseUrl();
    const defaultUrl = 'http://192.168.0.50/gastos2.0';
    ApiEndpoints.baseUrl = defaultUrl;
    _dioClient.updateBaseUrl(defaultUrl);

    state = state.copyWith(
      baseUrl: defaultUrl,
      clearStatus: true,
    );
  }

  Future<bool> probarConexion(String url) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    state = state.copyWith(isTestingConnection: true, clearStatus: true);

    try {
      final dioTest = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));

      final response = await dioTest.get<dynamic>('$cleanUrl/api/auth/me');

      final statusCode = response.statusCode ?? 0;
      final isAlive = statusCode >= 200 && statusCode < 500;

      state = state.copyWith(
        isTestingConnection: false,
        connectionOk: isAlive,
        connectionStatus: isAlive
            ? '¡Conexión exitosa! Servidor respondió código $statusCode'
            : 'Respuesta inesperada: código $statusCode',
      );
      return isAlive;
    } on DioException catch (e) {
      String mensaje = 'No se pudo conectar';
      if (e.type == DioExceptionType.connectionTimeout) {
        mensaje = 'Tiempo de espera agotado (Timeout)';
      } else if (e.type == DioExceptionType.connectionError) {
        mensaje = 'Conexión rechazada o sin ruta al host (Revisa IP y Wi-Fi)';
      } else if (e.response != null) {
        if (e.response!.statusCode == 401) {
          state = state.copyWith(
            isTestingConnection: false,
            connectionOk: true,
            connectionStatus: '¡Conexión exitosa con el servidor Apache! (401 OK)',
          );
          return true;
        }
        mensaje = 'Servidor respondió error ${e.response!.statusCode}';
      }

      state = state.copyWith(
        isTestingConnection: false,
        connectionOk: false,
        connectionStatus: mensaje,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isTestingConnection: false,
        connectionOk: false,
        connectionStatus: 'Error: $e',
      );
      return false;
    }
  }

  Future<void> cambiarThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _storageService.saveThemeMode(modeStr);
  }
}
