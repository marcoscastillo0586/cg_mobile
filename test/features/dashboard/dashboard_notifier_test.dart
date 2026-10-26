// Selección de cuentas y totales por moneda con un repositorio SIMULADO (sin SQLite ni red).
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/money/money.dart';
import 'package:gastos_mobile/features/dashboard/data/repositories/balances_repository.dart';
import 'package:gastos_mobile/features/dashboard/domain/entities/balances.dart';
import 'package:gastos_mobile/features/dashboard/presentation/providers/dashboard_notifier.dart';

class _Repo implements BalancesRepository {
  List<BalanceAccount> accounts = [];

  @override
  Future<Balances> getBalances({String? until}) async => Balances(until: until, accounts: accounts);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BalanceAccount _cuenta(int id, int cents, {Currency currency = Currency.ars}) =>
    BalanceAccount(id: id, name: 'c$id', currency: currency, imageUrl: null, iconRef: null, balanceCents: cents);

void main() {
  test('primera carga sin cuentas (descarga en curso): las que llegan después suman en el total', () async {
    final repo = _Repo();
    final n = DashboardNotifier(repo);
    await n.cargarDashboard();
    expect(n.state.totalSeleccionadoCents(Currency.ars), 0);

    repo.accounts = [_cuenta(1, 10000), _cuenta(2, 2550)];
    await n.cargarDashboard();
    expect(n.state.idsSeleccionados, {1, 2});
    expect(n.state.totalSeleccionadoCents(Currency.ars), 12550);
  });

  test('una cuenta desmarcada sigue afuera al recargar; una nueva entra marcada', () async {
    final repo = _Repo()..accounts = [_cuenta(1, 10000), _cuenta(2, 2550)];
    final n = DashboardNotifier(repo);
    await n.cargarDashboard();
    n.toggleCuentaSeleccionada(2);
    expect(n.state.totalSeleccionadoCents(Currency.ars), 10000);

    repo.accounts = [...repo.accounts, _cuenta(3, 500)];
    await n.cargarDashboard();
    expect(n.state.idsSeleccionados, {1, 3});
    expect(n.state.totalSeleccionadoCents(Currency.ars), 10500);

    n.toggleCuentaSeleccionada(2);
    expect(n.state.totalSeleccionadoCents(Currency.ars), 13050);
  });

  test(r'totales separados por moneda, sin conversión: $ 100,00 y US$ 20,00 (req. 4)', () async {
    final repo = _Repo()..accounts = [_cuenta(1, 10000), _cuenta(2, 2000, currency: Currency.usd)];
    final n = DashboardNotifier(repo);
    await n.cargarDashboard();
    expect((n.state.totalSeleccionadoCents(Currency.ars), n.state.totalSeleccionadoCents(Currency.usd)), (10000, 2000));

    n.toggleCuentaSeleccionada(1); // solo la de dólares tildada
    expect((n.state.totalSeleccionadoCents(Currency.ars), n.state.totalSeleccionadoCents(Currency.usd)), (0, 2000));
  });
}
