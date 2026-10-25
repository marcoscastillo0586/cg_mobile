import 'package:equatable/equatable.dart';
import '../../../core/errors/exceptions.dart';

/// Dashboard propio o compartido (DashboardDto de la API).
class Dashboard extends Equatable {
  final int id;
  final String name;
  final int ownerUserId;
  final String ownerName;

  /// El principal del dueño: no se elimina, solo se limpia.
  final bool principal;

  /// Rol del usuario: OWNER o MEMBER.
  final bool isOwner;
  final int membersCount;

  const Dashboard({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.ownerName,
    required this.principal,
    required this.isOwner,
    required this.membersCount,
  });

  /// Más de un integrante: cada movimiento muestra quién lo cargó.
  bool get shared => membersCount > 1;

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! int) throw const ServerException('Respuesta inesperada del servidor (dashboard)', null, 'UNEXPECTED_RESPONSE');
    return Dashboard(
      id: id,
      name: j['name'] as String? ?? '',
      ownerUserId: j['ownerUserId'] as int? ?? 0,
      ownerName: j['ownerName'] as String? ?? '',
      principal: j['principal'] == true,
      isOwner: j['role'] == 'OWNER',
      membersCount: j['membersCount'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [id, name, ownerUserId, ownerName, principal, isOwner, membersCount];
}

class DashboardMember extends Equatable {
  final int userId;
  final String name;
  final String email;
  final bool isOwner;

  const DashboardMember({required this.userId, required this.name, required this.email, required this.isOwner});

  factory DashboardMember.fromJson(Map<String, dynamic> j) => DashboardMember(
        userId: j['userId'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        isOwner: j['role'] == 'OWNER',
      );

  @override
  List<Object?> get props => [userId, name, email, isOwner];
}

/// Invitación pendiente recibida.
class DashboardInvitation extends Equatable {
  final int id;
  final int dashboardId;
  final String dashboardName;
  final String inviterName;
  final String inviterEmail;

  const DashboardInvitation({
    required this.id,
    required this.dashboardId,
    required this.dashboardName,
    required this.inviterName,
    required this.inviterEmail,
  });

  factory DashboardInvitation.fromJson(Map<String, dynamic> j) => DashboardInvitation(
        id: j['id'] as int? ?? 0,
        dashboardId: j['dashboardId'] as int? ?? 0,
        dashboardName: j['dashboardName'] as String? ?? '',
        inviterName: j['inviterName'] as String? ?? '',
        inviterEmail: j['inviterEmail'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, dashboardId, dashboardName, inviterName, inviterEmail];
}

/// Aviso del servidor: alguien aceptó o rechazó una invitación tuya.
class AppNotification extends Equatable {
  final int id;
  final bool accepted;
  final String userName;
  final String dashboardName;

  const AppNotification({required this.id, required this.accepted, required this.userName, required this.dashboardName});

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final data = j['data'] is Map ? (j['data'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return AppNotification(
      id: j['id'] as int? ?? 0,
      accepted: j['kind'] == 'INVITATION_ACCEPTED',
      userName: data['userName']?.toString() ?? '',
      dashboardName: data['dashboardName']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, accepted, userName, dashboardName];
}
