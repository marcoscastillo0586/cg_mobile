// Prueba EN VIVO contra la API de CG con dashboards (red y base reales). Se saltea si falta la variable.
//
//   CG_LIVE_DASH_API  p. ej. http://127.0.0.1:3002/api/v1  (servidor de PRUEBAS, nunca el real)
//
// Registra usuarios descartables y usa el mismo cliente que la app (DioClient, DashboardsRepository,
// CurrentDashboard). Corre en la PC: prueba el contrato app ↔ API, NO el celular.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/core/dashboards/live_events.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/network/transport_guard.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/movements/data/movements_repository.dart';

class _MemoryStorage extends SecureStorageService {
  final values = <String, String>{};
  _MemoryStorage() : super(const FlutterSecureStorage());

  @override
  Future<void> writeValue(String key, String value) async => values[key] = value;
  @override
  Future<String?> readValue(String key) async => values[key];
  @override
  Future<void> deleteValue(String key) async => values.remove(key);
}

class _User {
  final int id;
  final String email;
  final DioClient client;
  final DashboardsRepository dashboards;
  _User(this.id, this.email, this.client) : dashboards = DashboardsRepository(client, _MemoryStorage());
}

/// Contraseña de un usuario descartable de prueba: al azar en cada corrida (no queda escrita en el código).
String _throwawayPassword() {
  final r = Random.secure();
  return List.generate(24, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)]).join();
}

void main() {
  final api = Platform.environment['CG_LIVE_DASH_API'];
  final skip = api == null ? 'Falta CG_LIVE_DASH_API (API de PRUEBAS con dashboards)' : null;

  setUpAll(() {
    if (api != null) TransportGuard.httpAllowedHosts.add(Uri.parse(api).host);
  });
  tearDown(() => CurrentDashboard.id.value = null);

  Future<_User> register(String name) async {
    final email = 'live-${Random().nextInt(1 << 32)}@test.local';
    final res = await Dio(BaseOptions(baseUrl: api!, headers: {'X-Client': 'mobile'}))
        .post<Map<String, dynamic>>('/auth/register', data: {'name': name, 'email': email, 'password': _throwawayPassword()});
    final client = DioClient()..dio.options.baseUrl = api;
    client.dio.options.headers['Authorization'] = 'Bearer ${res.data!['accessToken']}';
    return _User(res.data!['user']['id'] as int, email, client);
  }

  test('compartir: invitar, aceptar, ver lo del dueño, autor, aviso y quitar acceso', skip: skip, () async {
    final owner = await register('Dueña Live');
    final guest = await register('Invitado Live');

    // El dueño tiene su principal y una cuenta.
    final principal = (await owner.dashboards.list()).single;
    expect([principal.principal, principal.isOwner, principal.name], [true, true, 'principal']);
    final account = await owner.client.post('/accounts', data: {'name': 'Banco Live', 'currency': 'ARS'}) as Map<String, dynamic>;
    final categories = await owner.client.get('/categories', queryParameters: {'purpose': 'expense'}) as List;
    final categoryId = (categories.first as Map)['id'] as int;

    // Invita por correo; al invitado le llega la invitación y la acepta.
    await owner.dashboards.invite(principal.id, guest.email);
    final [inv] = await guest.dashboards.invitations();
    expect([inv.dashboardId, inv.inviterName], [principal.id, 'Dueña Live']);
    final shared = await guest.dashboards.accept(inv.id);
    expect([shared.id, shared.isOwner, shared.shared, shared.ownerName], [principal.id, false, true, 'Dueña Live']);
    print('[LIVE] invitación aceptada: dashboard ${shared.id} compartido');

    // Con X-Dashboard-Id (CurrentDashboard) el invitado ve y carga en el dashboard del dueño.
    CurrentDashboard.id.value = shared.id;
    final accounts = await guest.client.get('/accounts') as List;
    expect(accounts.map((a) => (a as Map)['name']), ['Banco Live']);
    await guest.client.post('/expenses', data: {
      'accountId': account['id'],
      'date': '2026-10-25',
      'generalConcept': 'Compra live',
      'items': [
        {'concept': 'Pan', 'categoryId': categoryId, 'amount': '100.00'},
      ],
    });
    final page = await MovementsRepository(owner.client).getMovements(const MovementsQuery());
    final mov = page.items.single;
    expect([mov.createdByUserId, mov.createdByName], [guest.id, 'Invitado Live']);
    print('[LIVE] movimiento del invitado visto por la dueña: "Cargado por ${mov.createdByName}"');

    // El dueño no puede editar lo que cargó el invitado.
    CurrentDashboard.id.value = null;
    Object? notCreator;
    try {
      await owner.client.patch('/movements/${mov.id}', data: {'generalConcept': 'X'});
    } catch (e) {
      notCreator = e;
    }
    expect((notCreator! as ServerException).code, 'NOT_CREATOR');

    // A la dueña le llegó "aceptó"; al leerlo desaparece.
    final [note] = await owner.dashboards.notifications();
    expect([note.accepted, note.userName, note.dashboardName], [true, 'Invitado Live', 'principal']);
    await owner.dashboards.markRead(note.id);
    expect(await owner.dashboards.notifications(), isEmpty);

    // Quita el acceso: el pedido del invitado con ese dashboard falla y la app vuelve al principal.
    final members = await owner.dashboards.members(principal.id);
    await owner.dashboards.removeMember(principal.id, members.firstWhere((m) => !m.isOwner).userId);
    CurrentDashboard.id.value = shared.id;
    Object? forbidden;
    try {
      await guest.client.get('/accounts');
    } catch (e) {
      forbidden = e;
    }
    expect((forbidden! as ServerException).code, 'DASHBOARD_FORBIDDEN');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(CurrentDashboard.id.value, isNull, reason: 'se perdió el acceso: vuelve al principal');
    print('[LIVE] acceso quitado → DASHBOARD_FORBIDDEN y vuelta al principal');
  });

  test('avisos en vivo: la invitación llega al instante a la app conectada', skip: skip, () async {
    final owner = await register('Dueño SSE');
    final guest = await register('Invitada SSE');
    final principal = (await owner.dashboards.list()).single;
    final received = <LiveEvent>[];
    final events = LiveEvents(guest.client, received.add)..start();
    await Future<void>.delayed(const Duration(milliseconds: 500)); // conexión abierta
    final started = DateTime.now();
    await owner.dashboards.invite(principal.id, guest.email);
    while (received.isEmpty && DateTime.now().difference(started) < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    events.stop();
    expect(received.map((e) => (e.type, e.dashboardId)), [('invitation', principal.id)]);
    print('[LIVE] invitación recibida en vivo en ${DateTime.now().difference(started).inMilliseconds} ms');
  });
}
