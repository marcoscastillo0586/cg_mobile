import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    LocalDatabase.deleteAll,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;
  final Future<void> Function() _deleteLocalDatabase;

  AuthRepositoryImpl(this._remote, this._storage, this._deleteLocalDatabase);

  @override
  Stream<Object> get onSessionExpired => _remote.onExpired;

  @override
  Future<UserEntity> login(String email, String password) async {
    final user = await _remote.login(email, password);
    // Si la base local era de otro usuario (p. ej. su sesión expiró sin cerrar), se borra.
    final owner = await _storage.getOwnerUserId();
    if (owner != null && owner != user.idUsuario) {
      debugPrint('[AUTH] La base local pertenecía a otro usuario: se borra.');
      await _deleteLocalDatabase();
    }
    await _storage.saveOwnerUserId(user.idUsuario);
    await _storage.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<RestoredSession?> restoreSession() async {
    if (!await _remote.hasSession()) return null;

    final stored = await _readStoredUser();
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

  @override
  Future<LogoutOutcome> logout() async {
    final outcome = await _remote.logout();
    await _deleteLocalDatabase();
    await _storage.clearSessionData();
    return outcome;
  }

  Future<UserModel?> _readStoredUser() async {
    final raw = await _storage.getUserJson();
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
