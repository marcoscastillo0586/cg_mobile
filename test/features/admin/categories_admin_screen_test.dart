// Pantalla "Categorías" contra la base local REAL (ffi): filtros, alta, renombrar, activar/desactivar y baja
// quedan en la outbox; permisos de dueño e invitado en un dashboard compartido.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/auth/session_scope.dart';
import 'package:gastos_mobile/core/dashboards/current_dashboard.dart';
import 'package:gastos_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gastos_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:gastos_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:gastos_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:gastos_mobile/features/categories_admin/data/local_categories_repository.dart';
import 'package:gastos_mobile/features/categories_admin/domain/category_item.dart';
import 'package:gastos_mobile/features/categories_admin/presentation/providers/categories_admin_state.dart';
import 'package:gastos_mobile/features/categories_admin/presentation/screens/categories_admin_screen.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/app_env.dart';
import '../../helpers/local_seed.dart';
import '../../helpers/screen.dart';

class _Auth implements AuthRepository {
  @override
  Stream<Object> get onSessionExpired => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CategoryItem _cat({bool active = true, bool reserved = false}) =>
    CategoryItem(id: 1, serverId: 1, name: 'X', active: active, role: reserved ? CategoryRole.transfer : null, movementsCount: 0, version: 1);

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late SeededDb s;

  tearDown(() => CurrentDashboard.id.value = null);

  test('acciones del menú: dueño todas; invitado sólo las suyas, sin desactivar ni eliminar; reservadas ninguna', () {
    expect(accionesDe(_cat(), canEdit: true, isOwner: true), ['edit', 'toggle', 'delete']);
    expect(accionesDe(_cat(), canEdit: true, isOwner: false), ['edit']);
    expect(accionesDe(_cat(active: false), canEdit: true, isOwner: false), ['edit', 'toggle']); // activar sí
    expect(accionesDe(_cat(), canEdit: false, isOwner: false), isEmpty);
    expect(accionesDe(_cat(reserved: true), canEdit: true, isOwner: true), isEmpty);
  });

  test('filtros y contadores del estado', () {
    final st = CategoriesAdminState.initial().copyWith(categorias: [
      _cat(),
      const CategoryItem(id: 2, serverId: 2, name: 'Viajes', active: false, role: null, movementsCount: 0, version: 1),
    ]);
    expect((st.activasCount, st.inactivasCount), (1, 1));
    expect(st.copyWith(filtroEstado: 'activas').categoriasFiltradas.map((c) => c.id), [1]);
    expect(st.copyWith(filtroEstado: 'inactivas').categoriasFiltradas.map((c) => c.id), [2]);
    expect(st.copyWith(busqueda: ' via ').categoriasFiltradas.map((c) => c.id), [2]);
    expect(st.copyWith(error: 'x').copyWith(clearError: true).error, isNull);
  });

  Future<void> abrir(WidgetTester tester, {bool owner = true}) async {
    s = (await tester.runAsync(seededDb))!;
    addTearDown(() => tester.runAsync(s.db.close));
    final dash = Dashboard(id: 1, name: 'Casa', ownerUserId: owner ? 7 : 8, ownerName: 'Ana', principal: true, isOwner: owner, membersCount: 2);
    final repo = FakeDashboardsRepository(dashboards: [dash]);
    CurrentDashboard.id.value = 1;
    await pumpScreen(tester, const CategoriesAdminScreen(), settle: false, overrides: [
      ...localAppOverrides(s, FakeServer()),
      localCategoriesRepositoryProvider.overrideWithValue(Future.value(LocalCategoriesRepository(s.db))),
      authRepositoryProvider.overrideWithValue(_Auth()),
      initialAuthStateProvider.overrideWithValue(AuthState.authenticated(const UserEntity(idUsuario: 7, nombreUsuario: 'Ana', email: 'a@x.com'))),
      dashboardsRepositoryProvider.overrideWithValue(repo),
      dashboardsNotifierProvider.overrideWith((_) => DashboardsNotifier(repo, 7)..state = DashboardsState(dashboards: [dash])),
    ]);
    await settleIo(tester, 10);
  }

  Future<List<Map<String, Object?>>> ops(WidgetTester tester) async => (await tester.runAsync(() => s.db.query('outbox', orderBy: 'seq')))!;

  Future<void> menu(WidgetTester tester, String categoria, String accion) async {
    await tester.tap(find.byKey(ValueKey('menu-categoria-$categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(accion).last);
    await tester.pumpAndSettle();
  }

  testWidgets('lista, búsqueda y filtros por estado', (tester) async {
    await abrir(tester);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3)); // reservadas
    await tester.enterText(find.byType(TextField), 'sup');
    await tester.pump();
    expect(find.text('Comida'), findsNothing);
    expect(find.text('Super'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text(l.noCategories), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.textContaining(l.inactive2));
    await tester.pump();
    expect(find.text(l.noCategories), findsOneWidget);
  });

  testWidgets('alta y renombrar quedan en la outbox', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nueva-categoria')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('categoria-nombre')), 'Viajes');
    await tester.tap(find.byKey(const ValueKey('categoria-guardar')));
    await settleIo(tester, 10);
    expect(find.text('Viajes'), findsOneWidget);
    await menu(tester, 'Viajes', l.rename);
    await tester.enterText(find.byKey(const ValueKey('categoria-nombre')), 'Vacaciones');
    await tester.tap(find.byKey(const ValueKey('categoria-guardar')));
    await settleIo(tester, 10);
    expect(find.text('Vacaciones'), findsOneWidget);
    expect((await ops(tester)).map((o) => o['action']), ['create', 'update']);
  });

  testWidgets('desactivar, eliminar con confirmación; cancelar no hace nada', (tester) async {
    await abrir(tester);
    await menu(tester, 'Comida', l.deactivate);
    await settleIo(tester, 10);
    expect(find.text(l.categoryDeactivated), findsOneWidget);
    await menu(tester, 'Super', l.delete);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect((await ops(tester)).length, 1);
    await menu(tester, 'Super', l.delete);
    await tester.tap(find.byKey(const ValueKey('confirmar-accion')));
    await settleIo(tester, 10);
    expect(find.text('Super'), findsNothing);
    expect((await ops(tester)).length, 2);
  });

  testWidgets('nombre repetido: el motivo se muestra y no se encola', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('nueva-categoria')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('categoria-nombre')), 'Comida');
    await tester.tap(find.byKey(const ValueKey('categoria-guardar')));
    await settleIo(tester, 10);
    expect(await ops(tester), isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('invitado: sólo renombra las suyas (las del servidor sin autor también)', (tester) async {
    await abrir(tester, owner: false);
    await tester.tap(find.byKey(const ValueKey('menu-categoria-Comida')));
    await tester.pumpAndSettle();
    expect(find.text(l.rename), findsOneWidget);
    expect(find.text(l.delete), findsNothing);
    expect(find.text(l.deactivate), findsNothing);
  });
}
