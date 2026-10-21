import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';
import 'session_manager.dart';

/// Refresh token en el almacenamiento seguro (cifrado por el sistema).
class SecureRefreshTokenStorage implements RefreshTokenStorage {
  final SecureStorageService _storage;
  SecureRefreshTokenStorage(this._storage);

  @override
  Future<String?> read() => _storage.getRefreshToken();

  @override
  Future<void> write(String token) => _storage.saveRefreshToken(token);

  @override
  Future<void> delete() => _storage.deleteRefreshToken();
}

/// Una sola instancia por app: es la que garantiza un único refresh en vuelo.
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final authDio = DioClient.createDio();
  if (kDebugMode) authDio.interceptors.add(SafeLogInterceptor());
  final manager = SessionManager(
    authDio: authDio,
    storage: SecureRefreshTokenStorage(ref.watch(secureStorageServiceProvider)),
  );
  ref.onDispose(manager.dispose);
  return manager;
});
