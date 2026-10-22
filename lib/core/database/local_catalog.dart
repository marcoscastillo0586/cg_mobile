import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../money/money.dart';
import 'local_database.dart';

/// Referencia para la API: el id del servidor o, si todavía no se sincronizó, el clientId.
Map<String, Object> syncRef(int? serverId, String? clientId) =>
    serverId != null ? {'serverId': serverId} : {'clientId': clientId!};

/// Cuenta de la base local con su saldo (vista `account_balances`, incluye lo pendiente de enviar).
class LocalAccount extends Equatable {
  final int localId;
  final int? serverId;
  final String? clientId;
  final String name;
  final Currency currency;
  final bool active;
  final String? iconRef;
  final String? imageUrl;
  final int balanceCents;

  const LocalAccount({
    required this.localId,
    required this.serverId,
    required this.clientId,
    required this.name,
    required this.currency,
    required this.active,
    required this.iconRef,
    required this.imageUrl,
    required this.balanceCents,
  });

  Map<String, Object> get ref => syncRef(serverId, clientId);

  factory LocalAccount.fromRow(Map<String, Object?> r) => LocalAccount(
        localId: r['local_id']! as int,
        serverId: r['server_id'] as int?,
        clientId: r['client_id'] as String?,
        name: r['name']! as String,
        currency: Currency.parse(r['currency']),
        active: r['active'] == 1,
        iconRef: r['icon_ref'] as String?,
        imageUrl: r['image_url'] as String?,
        balanceCents: r['balance_cents']! as int,
      );

  @override
  List<Object?> get props => [localId, serverId, clientId, name, currency, active, iconRef, imageUrl, balanceCents];
}

/// Roles reservados del servidor (CategoryRole de @cg/shared).
abstract final class CategoryRoles {
  static const transfer = 'TRANSFER';
  static const income = 'INCOME';
  static const defaultTicket = 'DEFAULT_TICKET';
}

class LocalCategory extends Equatable {
  final int localId;
  final int? serverId;
  final String? clientId;
  final String name;
  final String? role;
  final bool active;

  const LocalCategory({
    required this.localId,
    required this.serverId,
    required this.clientId,
    required this.name,
    required this.role,
    required this.active,
  });

  /// TRANSFER e INCOME no se pueden usar en egresos (RESERVED_CATEGORY en el servidor).
  bool get reservedForExpenses => role == CategoryRoles.transfer || role == CategoryRoles.income;

  Map<String, Object> get ref => syncRef(serverId, clientId);

  factory LocalCategory.fromRow(Map<String, Object?> r) => LocalCategory(
        localId: r['local_id']! as int,
        serverId: r['server_id'] as int?,
        clientId: r['client_id'] as String?,
        name: r['name']! as String,
        role: r['role'] as String?,
        active: r['active'] == 1,
      );

  @override
  List<Object?> get props => [localId, serverId, clientId, name, role, active];
}

final localCatalogProvider = Provider<Future<LocalCatalog>>((ref) async => LocalCatalog(await ref.watch(localDatabaseProvider)));

/// Lecturas de catálogo para los formularios: todo sale de SQLite (funciona sin conexión).
class LocalCatalog {
  final DatabaseExecutor _db;
  LocalCatalog(this._db);

  static const _accountSelect = '''
    SELECT a.local_id, a.server_id, a.client_id, a.name, a.currency, a.active, a.icon_ref, a.image_url,
           b.balance_cents
    FROM accounts a JOIN account_balances b ON b.account_local_id = a.local_id
    WHERE a.deleted = 0''';

  /// Cuentas activas ordenadas por nombre (como la web).
  Future<List<LocalAccount>> activeAccounts() async =>
      (await _db.rawQuery('$_accountSelect AND a.active = 1 ORDER BY a.name COLLATE NOCASE')).map(LocalAccount.fromRow).toList();

  Future<LocalAccount?> account(int localId) async {
    final rows = await _db.rawQuery('$_accountSelect AND a.local_id = ?', [localId]);
    return rows.isEmpty ? null : LocalAccount.fromRow(rows.first);
  }

  /// Categorías que acepta un egreso: activas y no reservadas.
  Future<List<LocalCategory>> expenseCategories() async => (await _db.query(
        'categories',
        where: "deleted = 0 AND active = 1 AND (role IS NULL OR role NOT IN ('${CategoryRoles.transfer}', '${CategoryRoles.income}'))",
        orderBy: 'name COLLATE NOCASE',
      ))
          .map(LocalCategory.fromRow)
          .toList();

  Future<LocalCategory?> category(int localId) async {
    final rows = await _db.query('categories', where: 'local_id = ? AND deleted = 0', whereArgs: [localId]);
    return rows.isEmpty ? null : LocalCategory.fromRow(rows.first);
  }

  /// Categoría reservada por rol (INCOME, TRANSFER); null si el catálogo no se descargó.
  Future<LocalCategory?> roleCategory(String role) async {
    final rows = await _db.query('categories', where: 'role = ? AND deleted = 0', whereArgs: [role], limit: 1);
    return rows.isEmpty ? null : LocalCategory.fromRow(rows.first);
  }

  /// Conceptos usados en egresos, los más recientes primero (para autocompletar).
  Future<List<String>> recentExpenseConcepts({int limit = 300}) async => (await _db.rawQuery('''
        SELECT d.concept FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id
        WHERE h.type = 2 AND h.deleted = 0 AND d.deleted = 0 AND d.concept IS NOT NULL AND TRIM(d.concept) <> ''
        GROUP BY d.concept COLLATE NOCASE ORDER BY MAX(h.occurred_at) DESC LIMIT ?''', [limit]))
          .map((r) => r['concept']! as String)
          .toList();

  /// Categoría usada la última vez con ese concepto (sugerencia sin conexión), si sigue disponible.
  Future<int?> suggestCategory(String concept) async {
    final rows = await _db.rawQuery('''
      SELECT d.category_local_id AS id FROM movement_details d
      JOIN movement_headers h ON h.local_id = d.header_local_id
      JOIN categories c ON c.local_id = d.category_local_id
      WHERE h.type = 2 AND h.deleted = 0 AND d.deleted = 0 AND c.deleted = 0 AND c.active = 1
        AND (c.role IS NULL OR c.role NOT IN ('${CategoryRoles.transfer}', '${CategoryRoles.income}'))
        AND d.concept = ? COLLATE NOCASE
      ORDER BY h.occurred_at DESC LIMIT 1''', [concept.trim()]);
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }
}
