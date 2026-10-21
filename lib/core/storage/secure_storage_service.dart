import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../errors/exceptions.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return SecureStorageService(storage);
});

class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyOwnerUserId = 'local_data_owner_user_id';
  static const String _keyLastSyncedAt = 'last_synced_at_timestamp';
  static const String _keyUser = 'auth_user';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyLanguage = 'app_language';
  static const String _keyDefaultCurrency = 'app_default_currency';
  static const String _keyFirstLaunch = 'is_first_launch_done';

  SecureStorageService(this._storage);

  Future<void> writeValue(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<String?> readValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteValue(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<Map<String, String>> readAllKeys() async {
    try {
      return await _storage.readAll();
    } catch (_) {
      return {};
    }
  }

  // --- Sesión -----------------------------------------------------------------
  // El access token vive solo en memoria (SessionManager). Acá se guarda el refresh
  // token, que rota en cada uso: siempre se escribe el nuevo antes de usarlo.

  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      throw CacheException('No se pudo guardar la sesión: $e');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      throw CacheException('No se pudo leer la sesión: $e');
    }
  }

  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _keyRefreshToken);
    } catch (e) {
      throw CacheException('No se pudo borrar la sesión: $e');
    }
  }

  /// Usuario dueño de los datos de la base local (para no mezclar usuarios).
  Future<void> saveOwnerUserId(int userId) async {
    try {
      await _storage.write(key: _keyOwnerUserId, value: userId.toString());
    } catch (e) {
      throw CacheException('No se pudo guardar el dueño de los datos locales: $e');
    }
  }

  Future<int?> getOwnerUserId() async {
    try {
      final v = await _storage.read(key: _keyOwnerUserId);
      return v == null ? null : int.tryParse(v);
    } catch (e) {
      throw CacheException('No se pudo leer el dueño de los datos locales: $e');
    }
  }

  Future<void> saveUserJson(String userJson) async {
    try {
      await _storage.write(key: _keyUser, value: userJson);
    } catch (e) {
      throw CacheException('No se pudo guardar la sesión del usuario: $e');
    }
  }

  Future<String?> getUserJson() async {
    try {
      return await _storage.read(key: _keyUser);
    } catch (e) {
      throw CacheException('No se pudo leer la sesión del usuario: $e');
    }
  }

  Future<void> saveThemeMode(String mode) async {
    try {
      await _storage.write(key: _keyThemeMode, value: mode);
    } catch (e) {
      throw CacheException('No se pudo guardar el modo de tema: $e');
    }
  }

  Future<String?> getThemeMode() async {
    try {
      return await _storage.read(key: _keyThemeMode);
    } catch (e) {
      throw CacheException('No se pudo leer el modo de tema: $e');
    }
  }

  Future<void> saveLanguage(String lang) async {
    try {
      await _storage.write(key: _keyLanguage, value: lang);
    } catch (e) {
      throw CacheException('No se pudo guardar el idioma: $e');
    }
  }

  Future<String?> getLanguage() async {
    try {
      return await _storage.read(key: _keyLanguage);
    } catch (e) {
      throw CacheException('No se pudo leer el idioma: $e');
    }
  }

  Future<void> saveDefaultCurrency(String currency) async {
    try {
      await _storage.write(key: _keyDefaultCurrency, value: currency);
    } catch (e) {
      throw CacheException('No se pudo guardar la moneda por defecto: $e');
    }
  }

  Future<String?> getDefaultCurrency() async {
    try {
      return await _storage.read(key: _keyDefaultCurrency);
    } catch (e) {
      throw CacheException('No se pudo leer la moneda por defecto: $e');
    }
  }

  Future<void> saveFirstLaunchDone() async {
    try {
      await _storage.write(key: _keyFirstLaunch, value: 'true');
    } catch (e) {
      throw CacheException('No se pudo guardar estado del primer inicio: $e');
    }
  }

  Future<bool> isFirstLaunchDone() async {
    try {
      final val = await _storage.read(key: _keyFirstLaunch);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Borra todo lo de la sesión y de los datos del usuario. Conserva los ajustes
  /// del dispositivo (tema, idioma, moneda, onboarding).
  Future<void> clearSessionData() async {
    try {
      for (final key in [_keyRefreshToken, _keyUser, _keyOwnerUserId, _keyLastSyncedAt]) {
        await _storage.delete(key: key);
      }
    } catch (e) {
      throw CacheException('No se pudo borrar la sesión: $e');
    }
  }

}
