import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/session_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(secureStorageServiceProvider),
    LocalDatabase.adoptLegacyFiles,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;
  /// Pasa los archivos locales de antes de separar por cuenta a la cuenta dueña.
  final Future<void> Function(int ownerId) _adoptLegacyFiles;

  AuthRepositoryImpl(this._remote, this._storage, this._adoptLegacyFiles);

  @override
  Stream<Object> get onSessionExpired => _remote.onExpired;

  @override
  Future<UserEntity> updateDisplayName(String name) async {
    final user = await _remote.updateName(name);
    await _storage.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<UserEntity> updateMainCurrency(String currency) async {
    final user = await _remote.updateMainCurrency(currency);
    await _storage.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<UserEntity> login(String email, String password) async {
    // Los datos locales de antes (sin cuenta) son del dueño registrado, aunque ahora entre otra cuenta.
    final previous = await _readStoredUser();
    final user = await _remote.login(email, password);
    await _adoptLegacy(previous?.idUsuario ?? user.idUsuario);
    await _storage.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<RestoredSession?> restoreSession() async {
    if (!await _remote.hasSession()) return null;

    final stored = await _readStoredUser();
    if (stored != null) await _adoptLegacy(stored.idUsuario);
    try {
      await _remote.refresh();
      final user = await _remote.me();
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      return RestoredSession(user);
    } on SessionExpiredException {
      rethrow;
    } on NetworkException catch (e) {
      // Sin conexión: se sigue con el último usuario confirmado por el servidor.
      if (stored == null) rethrow;
      return RestoredSession(stored, offline: true, connectionError: e);
    } on ServerException catch (e) {
      // El servidor respondió con error (no de sesión): no se cierra la sesión, se informa.
      if (stored == null) rethrow;
      return RestoredSession(stored, offline: true, connectionError: e);
    }
  }

  /// Invalida la sesión en el servidor y borra los tokens. NO borra los datos locales de la cuenta,
  /// sus pendientes ni los ajustes: si vuelve a entrar, los encuentra (otra cuenta usa otros archivos).
  @override
  Future<LogoutOutcome> logout() async {
    final outcome = await _remote.logout();
    await _storage.clearSessionData();
    return outcome;
  }

  /// Una sola vez: los archivos y ajustes locales de antes de separar por cuenta pasan a su dueño
  /// (el registrado o, en instalaciones anteriores a ese registro, el usuario de la sesión guardada).
  Future<void> _adoptLegacy(int fallbackOwner) async {
    final owner = await _storage.getOwnerUserId() ?? fallbackOwner;
    await _adoptLegacyFiles(owner);
    await _storage.adoptLegacyAccountSettings(owner);
  }

  Future<UserModel?> _readStoredUser() async {
    final raw = await _storage.getUserJson();
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
