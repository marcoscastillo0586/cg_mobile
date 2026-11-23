// Repositorio de dashboards contra un servidor SIMULADO: rutas, contrato y copia de la lista por cuenta.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/current_account.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/core/network/dio_client.dart';
import 'package:gastos_mobile/core/storage/secure_storage_service.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import '../../helpers/app_env.dart';

Map<String, Object?> _d(int id, String name) =>
    {'id': id, 'name': name, 'ownerUserId': 7, 'ownerName': 'Ana', 'principal': id == 1, 'role': 'OWNER', 'membersCount': 1};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  late FakeServer server;
  late DashboardsRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    CurrentAccount.id = 7;
    server = FakeServer();
    repo = DashboardsRepository(DioClient(adapter: server)..dio.options.baseUrl = 'http://api.fake/api/v1', SecureStorageService(const FlutterSecureStorage()));
  });
  tearDown(() => CurrentAccount.id = null);

  test('la lista del servidor queda guardada por cuenta para usarla sin conexión', () async {
    expect(await repo.cached(), isEmpty);
    server.routes['/dashboards'] = (200, [_d(1, 'Casa'), _d(2, 'Viaje')]);
    expect((await repo.list()).map((d) => d.name), ['Casa', 'Viaje']);
    expect((await repo.cached()).map((d) => d.name), ['Casa', 'Viaje']);
    CurrentAccount.id = 8;
    expect(await repo.cached(), isEmpty); // otra cuenta del celular tiene su propia copia
  });

  test('alta, nombre, integrantes, invitaciones y avisos: rutas y contrato', () async {
    server.routes['/dashboards'] = (201, _d(3, 'Ahorro'));
    server.routes['/dashboards/3'] = (200, _d(3, 'Ahorro 2'));
    server.routes['/dashboards/3/members'] = (200, [{'userId': 7, 'name': 'Ana', 'email': 'a@x.com', 'role': 'OWNER'}]);
    server.routes['/invitations'] = (200, [{'id': 5, 'dashboardId': 3, 'dashboardName': 'Ahorro', 'inviterName': 'Beto', 'inviterEmail': 'b@x.com'}]);
    server.routes['/invitations/5/accept'] = (200, _d(3, 'Ahorro'));
    server.routes['/notifications'] = (200, [{'id': 9, 'kind': 'INVITATION_ACCEPTED', 'data': {'userName': 'Caro', 'dashboardName': 'Ahorro'}}]);
    for (final path in ['/dashboards/3/clear', '/dashboards/3/leave', '/dashboards/3/invitations', '/invitations/5/reject', '/notifications/9/read', '/dashboards/3/members/8']) {
      server.routes[path] = (204, '');
    }
    expect((await repo.create('Ahorro')).id, 3);
    expect((await repo.rename(3, 'Ahorro 2')).name, 'Ahorro 2');
    expect((await repo.members(3)).single.isOwner, isTrue);
    expect((await repo.invitations()).single.inviterName, 'Beto');
    expect((await repo.accept(5)).id, 3);
    expect((await repo.notifications()).single.accepted, isTrue);
    await repo.clear(3);
    await repo.leave(3);
    await repo.invite(3, 'c@x.com');
    await repo.reject(5);
    await repo.markRead(9);
    await repo.removeMember(3, 8);
    expect(server.requests.map((r) => '${r.method} ${r.path}'), containsAll([
      'POST /dashboards', 'PATCH /dashboards/3', 'POST /dashboards/3/clear', 'POST /dashboards/3/leave', 'POST /dashboards/3/invitations',
      'POST /invitations/5/reject', 'POST /notifications/9/read', 'DELETE /dashboards/3/members/8',
    ]));
    expect(server.requests.firstWhere((r) => r.path == '/dashboards/3/invitations').data, {'email': 'c@x.com'});
  });

  test('nombre pendiente: se guarda, se lee y null lo borra; respuesta con otra forma es error de contrato', () async {
    await repo.savePendingName('k', 'Casa');
    expect(await repo.readPendingName('k'), 'Casa');
    await repo.savePendingName('k', null);
    expect(await repo.readPendingName('k'), isNull);
    server.routes['/dashboards'] = (200, {'no': 'lista'});
    await expectLater(repo.list(), throwsA(isA<ServerException>().having((e) => e.code, 'code', 'UNEXPECTED_RESPONSE')));
    server.routes['/invitations/5/accept'] = (200, ['no', 'mapa']);
    await expectLater(repo.accept(5), throwsA(isA<ServerException>()));
  });
}
