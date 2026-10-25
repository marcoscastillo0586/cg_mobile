import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_reachability.dart';
import '../../domain/entities/balances.dart';
import '../models/balances_dto.dart';

final balancesRepositoryProvider = Provider<BalancesRepository>((ref) {
  return BalancesRepository(ref.watch(localDatabaseProvider), ref.watch(dioClientProvider));
});

/// Saldos del dashboard calculados desde la base LOCAL (funciona sin conexión e incluye lo
/// cargado en el celular y pendiente de enviar), con la misma regla que GET /accounts/balances
/// (accounts.service.ts): cuentas activas con saldo ≠ 0, corte opcional que incluye todo ese
/// día, y USD convertido con el redondeo de ExchangeRateService.toArsCents.
/// Solo la cotización viene del servidor. Cada cotización real recibida se guarda con su fecha
/// (sync_state); si ahora no se puede obtener (sin red, o el servidor no tiene dolarapi) se usa
/// esa última, indicando de cuándo es. Si nunca se recibió ninguna, los USD no se convierten:
/// no hay cotización fija. El motivo queda en [Balances.rateError].
class BalancesRepository {
  final Future<Database> _db;
  final DioClient _client;
  BalancesRepository(this._db, this._client);

  /// [until] en formato `yyyy-MM-dd`.
  Future<Balances> getBalances({String? until}) async {
    final db = await _db;
    final cutoff = until != null && until.isNotEmpty ? '$until 23:59:59' : null;
    final rows = await db.rawQuery('''
      SELECT a.local_id, a.name, a.currency, a.image_url, a.icon_ref,
             COALESCE(SUM(CASE WHEN d.deleted = 0 AND h.deleted = 0 ${cutoff != null ? 'AND h.occurred_at <= ?' : ''}
                               THEN d.amount_cents END), 0) AS balance
      FROM accounts a
      LEFT JOIN movement_details d ON d.account_local_id = a.local_id
      LEFT JOIN movement_headers h ON h.local_id = d.header_local_id
      WHERE a.active = 1 AND a.deleted = 0
      GROUP BY a.local_id
      HAVING balance <> 0
      ORDER BY a.name COLLATE NOCASE''', [if (cutoff != null) cutoff]);

    final needsRate = rows.any((r) => r['currency'] == Currency.usd.code);
    var rate = ExchangeRate.notApplicable;
    Object? rateError;
    if (needsRate && ServerReachability.recentlyOffline) {
      // Sin conexión confirmada: la última cotización guardada, sin esperar al servidor.
      rateError = const NetworkException();
      rate = await lastKnownRate(db);
    } else if (needsRate) {
      try {
        final fresh = BalancesDto.fromJson(await _client.get('/accounts/balances')).exchangeRate;
        if (fresh.isNotApplicable) {
          // El servidor no ve saldos en USD (p. ej. solo hay movimientos pendientes en el celular):
          // su 1,00 no es una cotización. Se usa la última real, si hay.
          rate = await lastKnownRate(db);
        } else if (fresh.available) {
          rate = fresh;
          await db.update('sync_state',
              {'rate_name': fresh.name, 'rate_sell_cents': fresh.sellCents, 'rate_received_at': DateTime.now().toUtc().toIso8601String()},
              where: 'id = 1');
        } else {
          // El servidor respondió con su contingencia (dolarapi caído): no es una cotización real.
          rateError = const ServerException('El servidor no tiene cotización disponible', null, 'RATE_UNAVAILABLE');
          rate = await lastKnownRate(db);
        }
      } catch (e) {
        debugPrint('[DASHBOARD] Sin cotización del servidor: $e');
        rateError = e;
        rate = await lastKnownRate(db);
      }
    }

    var total = 0;
    final accounts = [
      for (final r in rows)
        () {
          final currency = Currency.parse(r['currency']);
          final cents = r['balance']! as int;
          final int? ars = currency != Currency.usd ? cents : (rate.available ? toArsCents(cents, rate.sellCents) : null);
          total += ars ?? 0;
          return BalanceAccount(
            id: r['local_id']! as int,
            name: r['name']! as String,
            currency: currency,
            imageUrl: r['image_url'] as String?,
            iconRef: r['icon_ref'] as String?,
            balanceCents: cents,
            balanceArsCents: ars,
          );
        }(),
    ];
    return Balances(until: cutoff == null ? null : until, exchangeRate: rate, totalArsCents: total, accounts: accounts, rateError: rateError);
  }

  /// Última cotización real guardada (con su fecha), o [ExchangeRate.none] si no hay.
  static Future<ExchangeRate> lastKnownRate(DatabaseExecutor db) async {
    final r = (await db.query('sync_state', columns: ['rate_name', 'rate_sell_cents', 'rate_received_at'])).single;
    final cents = r['rate_sell_cents'] as int?;
    if (cents == null) return ExchangeRate.none;
    return ExchangeRate(name: r['rate_name'] as String? ?? '', sellCents: cents, available: true, receivedAt: r['rate_received_at'] as String?);
  }

  /// Igual que ExchangeRateService.toArsCents: producto entero y redondeo "mitad lejos de cero".
  static int toArsCents(int usdCents, int sellCents) {
    final product = BigInt.from(usdCents) * BigInt.from(sellCents);
    final hundred = BigInt.from(100);
    final q = product ~/ hundred; // trunca hacia cero, como BigInt de JS
    final r = product.remainder(hundred).abs();
    final rounded = r >= BigInt.from(50) ? q + (product.isNegative ? -BigInt.one : BigInt.one) : q;
    return rounded.toInt();
  }
}
