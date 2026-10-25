import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/dashboard.dart';

final dashboardsRepositoryProvider = Provider<DashboardsRepository>(
  (ref) => DashboardsRepository(ref.watch(dioClientProvider), ref.watch(secureStorageServiceProvider)),
);

/// Dashboards del usuario (docs/dashboards.md de CG): lista (con copia guardada para elegir sin
/// conexión), alta, nombre, limpieza, eliminación, integrantes, invitaciones y avisos.
/// Compartir, aceptar y avisos requieren conexión: el servidor valida al usuario registrado.
class DashboardsRepository {
  final DioClient _client;
  final SecureStorageService _storage;
  DashboardsRepository(this._client, this._storage);

  static const cacheKey = 'dashboards_cache';

  /// Lista del servidor; la guarda para usarla sin conexión.
  Future<List<Dashboard>> list() async {
    final body = await _client.get('/dashboards');
    final list = _list(body, 'dashboards').map(Dashboard.fromJson).toList();
    try {
      await _storage.writeValue(cacheKey, jsonEncode(body));
    } catch (e) {
      // Sin copia, sin conexión solo se ve el dashboard ya elegido.
      debugPrint('[DASHBOARDS] No se pudo guardar la lista: $e');
    }
    return list;
  }

  /// Última lista guardada (vacía si nunca se descargó).
  Future<List<Dashboard>> cached() async {
    final raw = await _storage.readValue(cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    return _list(jsonDecode(raw), 'dashboards').map(Dashboard.fromJson).toList();
  }

  /// Valor pendiente de enviar (p. ej. el nombre del principal elegido sin conexión). null lo borra.
  Future<void> savePendingName(String key, String? value) =>
      value == null ? _storage.deleteValue(key) : _storage.writeValue(key, value);

  Future<String?> readPendingName(String key) => _storage.readValue(key);

  Future<Dashboard> create(String name) async => Dashboard.fromJson(_map(await _client.post('/dashboards', data: {'name': name}), 'dashboard'));

  Future<Dashboard> rename(int id, String name) async =>
      Dashboard.fromJson(_map(await _client.patch('/dashboards/$id', data: {'name': name}), 'dashboard'));

  Future<void> remove(int id) => _client.delete('/dashboards/$id');

  Future<void> clear(int id) => _client.post('/dashboards/$id/clear');

  Future<List<DashboardMember>> members(int id) async =>
      _list(await _client.get('/dashboards/$id/members'), 'members').map(DashboardMember.fromJson).toList();

  Future<void> removeMember(int id, int userId) => _client.delete('/dashboards/$id/members/$userId');

  Future<void> leave(int id) => _client.post('/dashboards/$id/leave');

  Future<void> invite(int id, String email) => _client.post('/dashboards/$id/invitations', data: {'email': email});

  Future<List<DashboardInvitation>> invitations() async =>
      _list(await _client.get('/invitations'), 'invitations').map(DashboardInvitation.fromJson).toList();

  /// Devuelve el dashboard compartido al aceptar.
  Future<Dashboard> accept(int invitationId) async =>
      Dashboard.fromJson(_map(await _client.post('/invitations/$invitationId/accept'), 'dashboard'));

  Future<void> reject(int invitationId) => _client.post('/invitations/$invitationId/reject');

  Future<List<AppNotification>> notifications() async =>
      _list(await _client.get('/notifications'), 'notifications').map(AppNotification.fromJson).toList();

  /// Al tocar el aviso, desaparece.
  Future<void> markRead(int id) => _client.post('/notifications/$id/read');

  static List<Map<String, dynamic>> _list(Object? v, String f) =>
      v is List ? v.cast<Map<String, dynamic>>() : throw ServerException('Respuesta inesperada del servidor ($f)', null, 'UNEXPECTED_RESPONSE');

  static Map<String, dynamic> _map(Object? v, String f) =>
      v is Map<String, dynamic> ? v : throw ServerException('Respuesta inesperada del servidor ($f)', null, 'UNEXPECTED_RESPONSE');
}
