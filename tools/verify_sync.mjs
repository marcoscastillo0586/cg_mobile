#!/usr/bin/env node
// Compara la base local del CELULAR (cg_local.db) con la API del servidor de PRUEBAS.
//
// Uso:  node tools/verify_sync.mjs <API_BASE_URL> <archivo con JWT_ACCESS_SECRET> <userId> [ruta.db]
// - Sin [ruta.db] copia la base del celular por adb (run-as; app debug) a un temporal.
// - Consulta la API con un token de prueba firmado en memoria con el secreto del servidor de
//   pruebas (no usa contraseñas). Nunca usar contra el servidor real.
// Requiere Node >= 22.5 (node:sqlite).
import { createHmac } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const [api, secretFile, userIdArg, dbArg] = process.argv.slice(2);
if (!api || !secretFile || !userIdArg) {
  console.error('Uso: node tools/verify_sync.mjs <API_BASE_URL> <secreto.txt> <userId> [ruta.db]');
  process.exit(2);
}
const userId = Number(userIdArg);
const PKG = 'io.github.marcoscastillo0586.cg';

// ---------- token de prueba (HS256, mismo formato que AuthService) ----------
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const secret = readFileSync(secretFile, 'utf8').trim();
const iat = Math.floor(Date.now() / 1000);
const unsigned = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: userId, typ: 'access', iat, exp: iat + 300 })}`;
const token = `${unsigned}.${createHmac('sha256', secret).update(unsigned).digest('base64url')}`;
const get = async (path) => {
  const r = await fetch(`${api}${path}`, { headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' } });
  if (!r.ok) throw new Error(`${path} → HTTP ${r.status} ${await r.text()}`);
  return r.json();
};

// ---------- base local ----------
let dbPath = dbArg;
let tmp;
if (!dbPath) {
  tmp = mkdtempSync(join(tmpdir(), 'verify_sync_'));
  dbPath = join(tmp, 'cg_local.db');
  const bytes = execFileSync('adb', ['exec-out', 'run-as', PKG, 'cat', 'app_flutter/cg_local.db'], {
    env: { ...process.env, MSYS_NO_PATHCONV: '1' },
    maxBuffer: 512 * 1024 * 1024,
  });
  if (bytes.length < 1024) throw new Error(`No se pudo copiar la base del celular: ${bytes.toString().slice(0, 120)}`);
  writeFileSync(dbPath, bytes);
}
const db = new DatabaseSync(dbPath, { readOnly: true });
const one = (sql, ...a) => db.prepare(sql).get(...a);
const all = (sql, ...a) => db.prepare(sql).all(...a);
const live = 'd.deleted = 0 AND h.deleted = 0';

// ---------- servidor ----------
const [accounts, categories, budgets, balances, movs] = await Promise.all([
  get('/accounts'),
  get('/categories?purpose=all'),
  get('/budgets'),
  get('/accounts/balances'),
  get('/movements?includeInactiveAccounts=true&limit=1'),
]);

const rows = [];
const check = (tabla, dato, servidor, local) => rows.push({ tabla, dato, servidor, local, ok: String(servidor) === String(local) });

// Filas por tabla
check('accounts', 'filas', accounts.length, one('SELECT COUNT(*) n FROM accounts WHERE server_id IS NOT NULL AND deleted = 0').n);
check('categories', 'filas', categories.length, one('SELECT COUNT(*) n FROM categories WHERE server_id IS NOT NULL AND deleted = 0').n);
check('budgets', 'filas', budgets.length, one('SELECT COUNT(*) n FROM budgets WHERE server_id IS NOT NULL AND deleted = 0').n);
check('movement_headers', 'comprobantes con renglones', movs.total,
  one(`SELECT COUNT(DISTINCT h.local_id) n FROM movement_headers h JOIN movement_details d ON d.header_local_id = h.local_id WHERE ${live}`).n);
check('movement_details', 'renglones', accounts.reduce((a, x) => a + x.movementsCount, 0),
  one(`SELECT COUNT(*) n FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id WHERE ${live}`).n);
check('movement_details', 'suma de montos (centavos)', accounts.reduce((a, x) => a + x.balanceCents, 0),
  one(`SELECT COALESCE(SUM(d.amount_cents), 0) s FROM movement_details d JOIN movement_headers h ON h.local_id = d.header_local_id WHERE ${live}`).s);

// Saldo y renglones por cuenta (GET /accounts)
const localByAccount = new Map(
  all(`SELECT a.server_id id, COALESCE(SUM(CASE WHEN ${live} THEN d.amount_cents END), 0) bal,
              COUNT(CASE WHEN ${live} THEN d.local_id END) n
       FROM accounts a
       LEFT JOIN movement_details d ON d.account_local_id = a.local_id
       LEFT JOIN movement_headers h ON h.local_id = d.header_local_id
       WHERE a.server_id IS NOT NULL GROUP BY a.local_id`).map((r) => [r.id, r]),
);
for (const a of accounts) {
  const l = localByAccount.get(a.id) ?? { bal: 'falta', n: 'falta' };
  check('cuenta', `saldo ${a.name}`, a.balanceCents, l.bal);
  check('cuenta', `renglones ${a.name}`, a.movementsCount, l.n);
}
// Vista de saldos contra GET /accounts/balances (cuentas activas con saldo ≠ 0)
const view = new Map(all(`SELECT a.server_id id, b.balance_cents bal FROM account_balances b JOIN accounts a ON a.local_id = b.account_local_id`).map((r) => [r.id, r.bal]));
for (const a of balances.accounts) check('account_balances', `vista ${a.name}`, a.balanceCents, view.get(a.id) ?? 'falta');

db.close();
if (tmp) rmSync(tmp, { recursive: true, force: true });

// ---------- resultado ----------
const pad = (t, n) => { t = String(t); return t.length > n ? t.slice(0, n - 1) + '…' : t.padEnd(n); };
console.log(`${pad('Tabla', 17)} ${pad('Dato', 32)} ${pad('Servidor', 14)} ${pad('Local', 14)} Resultado`);
for (const r of rows) {
  const diff = r.ok ? 'OK' : `FALLA (diferencia: ${typeof r.servidor === 'number' && typeof r.local === 'number' ? r.local - r.servidor : 'falta'})`;
  console.log(`${pad(r.tabla, 17)} ${pad(r.dato, 32)} ${pad(r.servidor, 14)} ${pad(r.local, 14)} ${diff}`);
}
const bad = rows.filter((r) => !r.ok).length;
console.log(`\n${rows.length - bad} OK, ${bad} FALLA`);
process.exit(bad ? 1 : 0);
