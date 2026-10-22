#!/usr/bin/env node
// Muestra la cola de operaciones (outbox) y los comprobantes pendientes del CELULAR, leyendo
// su cg_local.db por adb (run-as; app debug). No usa la red ni la API.
//
// Uso:  node tools/outbox_dump.mjs [ruta.db]
// Requiere Node >= 22.5 (node:sqlite).
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const PKG = 'io.github.marcoscastillo0586.cg';
let dbPath = process.argv[2];
let tmp;
if (!dbPath) {
  tmp = mkdtempSync(join(tmpdir(), 'outbox_dump_'));
  dbPath = join(tmp, 'cg_local.db');
  // El WAL/journal no aplica: sqflite usa journal por defecto y la transacción ya confirmó.
  const bytes = execFileSync('adb', ['exec-out', 'run-as', PKG, 'cat', 'app_flutter/cg_local.db'], {
    env: { ...process.env, MSYS_NO_PATHCONV: '1' },
    maxBuffer: 512 * 1024 * 1024,
  });
  if (bytes.length < 1024) throw new Error(`No se pudo copiar la base del celular: ${bytes.toString().slice(0, 120)}`);
  writeFileSync(dbPath, bytes);
}
const db = new DatabaseSync(dbPath, { readOnly: true });

console.log(`Base: user_version=${db.prepare('PRAGMA user_version').get().user_version}, integrity=${db.prepare('PRAGMA integrity_check').get().integrity_check}`);
console.log('\nOUTBOX (en orden de envío)');
for (const o of db.prepare('SELECT seq, op_id, entity, action, client_id, status, created_at, data FROM outbox ORDER BY seq').all()) {
  console.log(`#${o.seq} ${o.status.padEnd(8)} ${o.entity}/${o.action} op_id=${o.op_id} client_id=${o.client_id} creada=${o.created_at}`);
  console.log(`    data=${o.data}`);
}
console.log('\nCOMPROBANTES SIN server_id (pendientes)');
for (const h of db.prepare(`SELECT h.local_id, h.client_id, h.type, h.occurred_at, h.general_concept,
    GROUP_CONCAT(a.name || ':' || d.amount_cents, ' | ') AS renglones
  FROM movement_headers h JOIN movement_details d ON d.header_local_id = h.local_id JOIN accounts a ON a.local_id = d.account_local_id
  WHERE h.server_id IS NULL GROUP BY h.local_id ORDER BY h.local_id`).all()) {
  console.log(`local_id=${h.local_id} tipo=${h.type} ${h.occurred_at} "${h.general_concept}" client_id=${h.client_id} renglones: ${h.renglones}`);
}
const huerfanas = db.prepare(`SELECT COUNT(*) n FROM movement_headers h WHERE h.server_id IS NULL
  AND NOT EXISTS (SELECT 1 FROM outbox o WHERE o.client_id = h.client_id)`).get().n;
console.log(`\nComprobantes pendientes sin operación en la outbox: ${huerfanas}`);
db.close();
if (tmp) rmSync(tmp, { recursive: true, force: true });
