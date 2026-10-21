/// Migraciones versionadas de la base local. Se aplican en orden y cada una lleva la base
/// de la versión N-1 a la N. NUNCA se edita una migración ya publicada: los cambios
/// nuevos van en una migración nueva al final de la lista.
///
/// Convenciones:
/// - Importes en centavos: INTEGER con CHECK(typeof(..) = 'integer'); nunca REAL.
/// - Identidad: `local_id` (clave local), `server_id` (id de la API, null hasta sincronizar)
///   y `client_id` (UUID generado en el celular para las altas; null en lo que vino del
///   servidor sin clientId). Al menos uno de server_id/client_id es obligatorio.
/// - `version`: versión del servidor (para baseVersion); null si nunca se sincronizó.
/// - Eliminado lógico: `deleted` + `deleted_at` (el borrado físico lo decide el pull).
/// - Sin tablas de caché de valores derivados: los saldos salen de una VISTA.
class Migration {
  final int version;
  final String description;
  final List<String> statements;
  const Migration(this.version, this.description, this.statements);
}

const _identity = '''
  local_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  server_id  INTEGER UNIQUE,
  client_id  TEXT UNIQUE,
  version    INTEGER,
''';

const _logicalDelete = '''
  deleted    INTEGER NOT NULL DEFAULT 0 CHECK (deleted IN (0, 1)),
  deleted_at TEXT,
''';

const migrations = <Migration>[
  Migration(1, 'Catálogos y movimientos', [
    '''
CREATE TABLE accounts (
$_identity
  name       TEXT NOT NULL,
  currency   TEXT NOT NULL CHECK (currency IN ('ARS', 'USD')),
  active     INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  icon_ref   TEXT,
  image_url  TEXT,
$_logicalDelete
  updated_at TEXT NOT NULL,
  CHECK (server_id IS NOT NULL OR client_id IS NOT NULL)
)''',
    '''
CREATE TABLE categories (
$_identity
  name       TEXT NOT NULL,
  active     INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  role       TEXT CHECK (role IS NULL OR role IN ('TRANSFER', 'INCOME', 'DEFAULT_TICKET')),
$_logicalDelete
  updated_at TEXT NOT NULL,
  CHECK (server_id IS NOT NULL OR client_id IS NOT NULL)
)''',
    '''
CREATE TABLE budgets (
$_identity
  start_date  TEXT NOT NULL CHECK (length(start_date) = 10),
  end_date    TEXT NOT NULL CHECK (length(end_date) = 10),
  limit_cents INTEGER NOT NULL CHECK (typeof(limit_cents) = 'integer' AND limit_cents > 0),
$_logicalDelete
  updated_at  TEXT NOT NULL,
  CHECK (end_date >= start_date),
  CHECK (server_id IS NOT NULL OR client_id IS NOT NULL)
)''',
    '''
CREATE TABLE budget_categories (
  budget_local_id   INTEGER NOT NULL REFERENCES budgets (local_id) ON DELETE CASCADE,
  category_local_id INTEGER NOT NULL REFERENCES categories (local_id),
  PRIMARY KEY (budget_local_id, category_local_id)
)''',
    '''
CREATE TABLE budget_accounts (
  budget_local_id  INTEGER NOT NULL REFERENCES budgets (local_id) ON DELETE CASCADE,
  account_local_id INTEGER NOT NULL REFERENCES accounts (local_id),
  PRIMARY KEY (budget_local_id, account_local_id)
)''',
    '''
CREATE TABLE movement_headers (
$_identity
  type            INTEGER NOT NULL CHECK (type IN (1, 2, 3)),
  occurred_at     TEXT NOT NULL CHECK (length(occurred_at) = 19),
  general_concept TEXT,
$_logicalDelete
  updated_at      TEXT NOT NULL,
  CHECK (server_id IS NOT NULL OR client_id IS NOT NULL)
)''',
    '''
CREATE TABLE movement_details (
  local_id          INTEGER PRIMARY KEY AUTOINCREMENT,
  server_id         INTEGER UNIQUE,
  header_local_id   INTEGER NOT NULL REFERENCES movement_headers (local_id) ON DELETE CASCADE,
  account_local_id  INTEGER NOT NULL REFERENCES accounts (local_id),
  category_local_id INTEGER REFERENCES categories (local_id),
  concept           TEXT,
  amount_cents      INTEGER NOT NULL CHECK (typeof(amount_cents) = 'integer'),
  plu               TEXT,
  unit_price_cents  INTEGER CHECK (unit_price_cents IS NULL OR typeof(unit_price_cents) = 'integer'),
  image_url         TEXT,
$_logicalDelete
  updated_at        TEXT NOT NULL
)''',
    'CREATE INDEX idx_details_header ON movement_details (header_local_id)',
    'CREATE INDEX idx_details_account ON movement_details (account_local_id)',
    'CREATE INDEX idx_details_category ON movement_details (category_local_id)',
    'CREATE INDEX idx_headers_occurred ON movement_headers (occurred_at)',
    // Saldo por cuenta calculado en vivo (no es caché: no puede quedar viejo).
    '''
CREATE VIEW account_balances AS
SELECT a.local_id AS account_local_id,
       COALESCE(SUM(CASE WHEN d.deleted = 0 AND h.deleted = 0 THEN d.amount_cents END), 0) AS balance_cents
FROM accounts a
LEFT JOIN movement_details d ON d.account_local_id = a.local_id
LEFT JOIN movement_headers h ON h.local_id = d.header_local_id
GROUP BY a.local_id''',
  ]),
  Migration(2, 'Cola de operaciones y estado de sincronización', [
    // seq fija el orden de envío (el servidor procesa en el orden recibido).
    '''
CREATE TABLE outbox (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  op_id        TEXT NOT NULL UNIQUE,
  entity       TEXT NOT NULL CHECK (entity IN ('account', 'category', 'budget', 'movement', 'movement_detail')),
  action       TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete')),
  client_id    TEXT,
  ref          TEXT,
  base_version INTEGER,
  data         TEXT NOT NULL DEFAULT '{}',
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'applied', 'duplicate', 'conflict', 'rejected')),
  error        TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  CHECK (action <> 'create' OR client_id IS NOT NULL),
  CHECK (action = 'create' OR ref IS NOT NULL)
)''',
    'CREATE INDEX idx_outbox_status ON outbox (status, seq)',
    '''
CREATE TABLE sync_state (
  id           INTEGER PRIMARY KEY CHECK (id = 1),
  cursor       TEXT,
  last_pull_at TEXT,
  last_push_at TEXT
)''',
    'INSERT INTO sync_state (id) VALUES (1)',
  ]),
];

/// Versión de esquema que espera esta compilación de la app.
int get latestSchemaVersion => migrations.last.version;
