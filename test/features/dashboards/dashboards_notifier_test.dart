// Dashboards compartidos en la app con un repositorio SIMULADO (sin servidor ni almacenamiento real).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/dashboards/data/dashboards_repository.dart';
import 'package:gastos_mobile/features/dashboards/domain/dashboard.dart';
import 'package:gastos_mobile/features/dashboards/presentation/dashboards_notifier.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';

Map<String, dynamic> _json(int id, String name, {required int owner, String ownerName = 'Ana', bool principal = true, String role = 'OWNER', int members = 1}) =>
    {'id': id, 'name': name, 'ownerUserId': owner, 'ownerName': ownerName, 'principal': principal, 'role': role, 'membersCount': members};

class _Repo implements DashboardsRepository {
  List<Dashboard> server = [];
  List<Dashboard> saved = [];
  bool online = true;
  final pending = <String, String?>{};
  final renamed = <(int, String)>[];

  Future<T> _call<T>(T Function() f) async => online ? f() : throw const NetworkException();

  @override
  Future<List<Dashboard>> list() => _call(() => server);
  @override
  Future<List<Dashboard>> cached() async => saved;
  @override
  Future<List<DashboardInvitation>> invitations() => _call(() => const []);
  @override
  Future<List<AppNotification>> notifications() => _call(() => const []);
  @override
  Future<void> savePendingName(String key, String? value) async => pending[key] = value;
  @override
  Future<String?> readPendingName(String key) async => pending[key];
  @override
  Future<Dashboard> rename(int id, String name) => _call(() {
        renamed.add((id, name));
        final d = server.firstWhere((x) => x.id == id);
        return Dashboard(
            id: d.id, name: name, ownerUserId: d.ownerUserId, ownerName: d.ownerName, principal: d.principal, isOwner: d.isOwner, membersCount: d.membersCount);
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  test('DashboardDto de la API: rol, principal y compartido', () {
    final d = Dashboard.fromJson(_json(7, 'principal', owner: 2, ownerName: 'Beto', role: 'MEMBER', members: 2));
    expect([d.id, d.name, d.ownerName, d.principal, d.isOwner, d.shared], [7, 'principal', 'Beto', true, false, true]);
  });

  test('dos "principal": se distinguen con el dueño entre paréntesis o "(tú)"', () async {
    final repo = _Repo()
      ..server = [
        Dashboard.fromJson(_json(1, 'principal', owner: 1)),
        Dashboard.fromJson(_json(5, 'Principal', owner: 2, ownerName: 'Beto', role: 'MEMBER', members: 2)),
        Dashboard.fromJson(_json(9, 'Vacaciones', owner: 1, principal: false)),
      ];
    final n = DashboardsNotifier(repo, 1);
    await n.refresh();
    final [mine, shared, other] = n.state.dashboards;
    expect(n.label(mine, l), 'principal (tú)');
    expect(n.label(shared, l), 'Principal (Beto)');
    expect(n.label(other, l), 'Vacaciones');
    expect(n.isMyPrincipal(mine), isTrue);
    expect(n.isMyPrincipal(shared), isFalse);
    n.dispose();
  });

  test('sin conexión se usa la lista guardada y no se informa error', () async {
    final repo = _Repo()
      ..online = false
      ..saved = [Dashboard.fromJson(_json(1, 'principal', owner: 1))];
    final n = DashboardsNotifier(repo, 1);
    await n.refresh();
    expect(n.state.dashboards.map((d) => d.id), [1]);
    expect(n.state.error, isNull);
    n.dispose();
  });

  test('nombre del principal elegido sin conexión: queda pendiente y se envía al volver', () async {
    final repo = _Repo()
      ..online = false
      ..server = [Dashboard.fromJson(_json(1, 'principal', owner: 1))];
    final n = DashboardsNotifier(repo, 1);
    await n.namePrincipal('Casa');
    expect(repo.renamed, isEmpty);
    expect(repo.pending.values.single, 'Casa');

    repo.online = true;
    await n.refresh();
    expect(repo.renamed, [(1, 'Casa')]);
    expect(repo.pending.values.single, isNull);
    expect(n.state.dashboards.single.name, 'Casa');
    n.dispose();
  });
}
