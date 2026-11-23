// Contrato con la API de dashboards: integrantes, invitaciones y avisos, con valores por defecto si falta algo.
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';

void main() {
  test('integrante: dueño por rol; campos faltantes vacíos', () {
    expect(DashboardMember.fromJson({'userId': 3, 'name': 'Ana', 'email': 'a@b.c', 'role': 'OWNER'}),
        const DashboardMember(userId: 3, name: 'Ana', email: 'a@b.c', isOwner: true));
    expect(DashboardMember.fromJson({'role': 'MEMBER'}), const DashboardMember(userId: 0, name: '', email: '', isOwner: false));
  });

  test('invitación recibida', () {
    expect(
      DashboardInvitation.fromJson({'id': 4, 'dashboardId': 9, 'dashboardName': 'Casa', 'inviterName': 'Beto', 'inviterEmail': 'b@c.d'}),
      const DashboardInvitation(id: 4, dashboardId: 9, dashboardName: 'Casa', inviterName: 'Beto', inviterEmail: 'b@c.d'),
    );
    expect(DashboardInvitation.fromJson({}), const DashboardInvitation(id: 0, dashboardId: 0, dashboardName: '', inviterName: '', inviterEmail: ''));
  });

  test('aviso: aceptó o rechazó, con quién y qué dashboard; datos ausentes o con otra forma', () {
    expect(
      AppNotification.fromJson({'id': 2, 'kind': 'INVITATION_ACCEPTED', 'data': {'userName': 'Ana', 'dashboardName': 'Casa'}}),
      const AppNotification(id: 2, accepted: true, userName: 'Ana', dashboardName: 'Casa'),
    );
    expect(AppNotification.fromJson({'id': 3, 'kind': 'INVITATION_REJECTED', 'data': 'x'}),
        const AppNotification(id: 3, accepted: false, userName: '', dashboardName: ''));
    expect(AppNotification.fromJson({'data': {'userName': 5}}), const AppNotification(id: 0, accepted: false, userName: '5', dashboardName: ''));
  });
}
