// Entorno de las pantallas de administración (cuentas, categorías, límites): base local REAL, servidor
// simulado, usuario 7 conectado y un dashboard elegido del que es dueño o invitado.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'app_env.dart';
import 'local_seed.dart';
import 'screen.dart';

class _Auth implements AuthRepository {
  @override
  Stream<Object> get onSessionExpired => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Elige el dashboard 1 (hay que volver a null en el tearDown: CurrentDashboard.id es global).
List<Override> adminOverrides(SeededDb s, {bool owner = true}) {
  final dash = Dashboard(id: 1, name: 'Casa', ownerUserId: owner ? 7 : 8, ownerName: 'Ana', principal: true, isOwner: owner, membersCount: 2);
  final repo = FakeDashboardsRepository(dashboards: [dash]);
  CurrentDashboard.id.value = 1;
  return [
    ...localAppOverrides(s, FakeServer()),
    authRepositoryProvider.overrideWithValue(_Auth()),
    initialAuthStateProvider.overrideWithValue(AuthState.authenticated(const UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com'))),
    dashboardsRepositoryProvider.overrideWithValue(repo),
    dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(repo, 7)..state = DashboardsState(dashboards: [dash])),
  ];
}
