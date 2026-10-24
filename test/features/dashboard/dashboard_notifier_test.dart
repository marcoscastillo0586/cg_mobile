// Selección de cuentas del consolidado con un repositorio SIMULADO (sin SQLite ni red).
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/balances.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/dashboard_notifier.dart';

class _Repo implements BalancesRepository {
  List<BalanceAccount> accounts = [];

  @override
  Future<Balances> getBalances({String? until}) async => Balances(
        until: until,
        exchangeRate: ExchangeRate.notApplicable,
        totalArsCents: accounts.fold(0, (s, a) => s + a.balanceArsCents!),
        accounts: accounts,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BalanceAccount _cuenta(int id, int cents) => BalanceAccount(
    id: id, name: 'c$id', currency: Currency.ars, imageUrl: null, iconRef: null, balanceCents: cents, balanceArsCents: cents);

void main() {
  test('primera carga sin cuentas (descarga en curso): las que llegan después suman en el total', () async {
    final repo = _Repo();
    final n = DashboardNotifier(repo);
    await n.cargarDashboard();
    expect(n.state.totalSeleccionadoArsCents, 0);

    repo.accounts = [_cuenta(1, 10000), _cuenta(2, 2550)];
    await n.cargarDashboard();
    expect(n.state.idsSeleccionados, {1, 2});
    expect(n.state.totalSeleccionadoArsCents, 12550);
  });

  test('una cuenta desmarcada sigue afuera al recargar; una nueva entra marcada', () async {
    final repo = _Repo()..accounts = [_cuenta(1, 10000), _cuenta(2, 2550)];
    final n = DashboardNotifier(repo);
    await n.cargarDashboard();
    n.toggleCuentaSeleccionada(2);
    expect(n.state.totalSeleccionadoArsCents, 10000);

    repo.accounts = [...repo.accounts, _cuenta(3, 500)];
    await n.cargarDashboard();
    expect(n.state.idsSeleccionados, {1, 3});
    expect(n.state.totalSeleccionadoArsCents, 10500);

    n.toggleCuentaSeleccionada(2);
    expect(n.state.totalSeleccionadoArsCents, 13050);
  });
}
