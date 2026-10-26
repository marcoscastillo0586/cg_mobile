import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/balances.dart';

final balancesRepositoryProvider = Provider<BalancesRepository>((ref) {
  return BalancesRepository(ref.watch(localDatabaseProvider));
});

/// Saldos del dashboard calculados desde la base LOCAL (funciona sin conexión e incluye lo
/// cargado en el celular y pendiente de enviar), con la misma regla que GET /accounts/balances
/// (accounts.service.ts): cuentas activas con saldo ≠ 0 y corte opcional que incluye todo ese
/// día. Cada saldo en la moneda de su cuenta: no hay cotización ni conversión entre monedas.
class BalancesRepository {
  final Future<Database> _db;
  BalancesRepository(this._db);

  /// [until] en formato `yyyy-MM-dd`.
  Future<Balances> getBalances({String? until}) async {
    final db = await _db;
    final cutoff = until != null && until.isNotEmpty ? '$until 23:59:59' : null;
    final rows = await db.rawQuery('''
      SELECT a.local_id, a.server_id, a.name, a.currency, a.image_url, a.icon_ref,
             COALESCE(SUM(CASE WHEN d.deleted = 0 AND h.deleted = 0 ${cutoff != null ? 'AND h.occurred_at <= ?' : ''}
                               THEN d.amount_cents END), 0) AS balance
      FROM accounts a
      LEFT JOIN movement_details d ON d.account_local_id = a.local_id
      LEFT JOIN movement_headers h ON h.local_id = d.header_local_id
      WHERE a.active = 1 AND a.deleted = 0
      GROUP BY a.local_id
      HAVING balance <> 0
      ORDER BY a.name COLLATE NOCASE''', [if (cutoff != null) cutoff]);

    return Balances(
      until: cutoff == null ? null : until,
      accounts: [
        for (final r in rows)
          BalanceAccount(
            id: r['local_id']! as int,
            serverId: r['server_id'] as int?,
            name: r['name']! as String,
            currency: Currency.parse(r['currency']),
            imageUrl: r['image_url'] as String?,
            iconRef: r['icon_ref'] as String?,
            balanceCents: r['balance']! as int,
          ),
      ],
    );
  }
}
