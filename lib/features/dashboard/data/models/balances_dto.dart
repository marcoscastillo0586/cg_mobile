import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/balances.dart';

/// Parseo estricto de `BalancesDto` (@cg/shared). Un campo con otro tipo es un error de
/// contrato: se informa, no se reemplaza por un valor inventado.
class BalancesDto {
  BalancesDto._();

  static Balances fromJson(Object? json) {
    final m = _map(json, 'balances');
    final rate = _map(m['exchangeRate'], 'exchangeRate');
    final accounts = m['accounts'];
    if (accounts is! List) throw _bad('accounts');
    return Balances(
      until: m['until'] as String?,
      exchangeRate: ExchangeRate(
        name: rate['name'] as String? ?? '',
        sellCents: Money.centsFrom(rate['sellCents'], 'exchangeRate.sellCents'),
        available: rate['available'] == true,
      ),
      totalArsCents: Money.centsFrom(m['totalArsCents'], 'totalArsCents'),
      accounts: accounts.map((a) => _account(_map(a, 'account'))).toList(),
    );
  }

  static BalanceAccount _account(Map<String, dynamic> a) => BalanceAccount(
        id: a['id'] is int ? a['id'] as int : throw _bad('account.id'),
        serverId: a['id'] as int,
        name: a['name'] as String? ?? '',
        currency: Currency.parse(a['currency']),
        imageUrl: a['imageUrl'] as String?,
        iconRef: a['iconRef'] as String?,
        balanceCents: Money.centsFrom(a['balanceCents'], 'account.balanceCents'),
        balanceArsCents: Money.centsFrom(a['balanceArsCents'], 'account.balanceArsCents'),
      );

  static Map<String, dynamic> _map(Object? v, String field) =>
      v is Map<String, dynamic> ? v : throw _bad(field);

  static ServerException _bad(String field) =>
      ServerException('Respuesta inesperada del servidor ($field)', null, 'UNEXPECTED_RESPONSE');
}
