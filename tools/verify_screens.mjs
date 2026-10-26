#!/usr/bin/env node
// Compara lo que muestran las pantallas de la app EN EL CELULAR con el JSON de la API.
//
// Uso:  node tools/verify_screens.mjs <API_BASE_URL> <credenciales.json>
//   credenciales.json = {"email": "...", "password": "..."}   (no se imprime nunca)
// o:    node tools/verify_screens.mjs <API_BASE_URL> <archivo con JWT_ACCESS_SECRET> <userId>
//   token de prueba firmado en memoria con el secreto del servidor de PRUEBAS (sin contraseñas).
// Requisitos: celular por adb con la app abierta y la sesión iniciada con el MISMO usuario.
// Nunca usar contra la base real: solo contra el servidor de pruebas.
import { createHmac } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const [api, credFile, userIdArg] = process.argv.slice(2);
if (!api || !credFile) {
  console.error('Uso: node tools/verify_screens.mjs <API_BASE_URL> <credenciales.json> | <secreto.txt> <userId>');
  process.exit(2);
}
const PKG = 'io.github.marcoscastillo0586.cg';
const env = { ...process.env, MSYS_NO_PATHCONV: '1' };

// ---------- Formato: misma regla que lib/core/money/money.dart ----------
const group = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
function money(cents, currency = 'ARS') {
  const sym = currency === 'USD' ? 'US$' : '$';
  const abs = Math.abs(cents);
  return `${cents < 0 ? '-' : ''}${sym} ${group(Math.trunc(abs / 100))},${String(abs % 100).padStart(2, '0')}`;
}
function percent(v) {
  const h = Math.round(v * 100);
  const a = Math.abs(h);
  return `${h < 0 ? '-' : ''}${group(Math.trunc(a / 100))},${String(a % 100).padStart(2, '0')} %`;
}

// ---------- API ----------
const H = { 'Content-Type': 'application/json', 'X-Client': 'mobile' };
let login = null;
let accessToken;
if (userIdArg) {
  // Token de prueba (HS256, mismo formato que AuthService), firmado en memoria.
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const secret = readFileSync(credFile, 'utf8').trim();
  const iat = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub: Number(userIdArg), typ: 'access', iat, exp: iat + 900 })}`;
  accessToken = `${unsigned}.${createHmac('sha256', secret).update(unsigned).digest('base64url')}`;
} else {
  const cred = JSON.parse(readFileSync(credFile, 'utf8'));
  login = await (await fetch(`${api}/auth/login`, { method: 'POST', headers: H, body: JSON.stringify(cred) })).json();
  if (!login.accessToken) throw new Error(`login falló: ${login.code}`);
  accessToken = login.accessToken;
}
const auth = { ...H, Authorization: `Bearer ${accessToken}` };
const get = async (p) => {
  const r = await fetch(`${api}${p}`, { headers: auth });
  if (!r.ok) throw new Error(`${p} → HTTP ${r.status}`);
  return r.json();
};

// ---------- adb / uiautomator ----------
const adb = (...a) => execFileSync('adb', a, { env, encoding: 'utf8' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const decode = (s) => s.replace(/&#10;/g, '\n').replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#39;/g, "'");
function dump() {
  adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml');
  return adb('shell', 'cat', '/sdcard/ui.xml');
}
function texts(xml) {
  const out = [];
  for (const m of xml.matchAll(/(?:text|content-desc)="([^"]*)"/g)) if (m[1]) out.push(decode(m[1]));
  return out;
}
function foreground() {
  return adb('shell', 'dumpsys', 'window').split('\n').some((l) => l.includes('mCurrentFocus') && l.includes(`${PKG}/`));
}
/** Busca el nodo cuyo texto empieza con [label] (o lo contiene, con includes) y lo toca.
 *  Si no está visible (fuera de pantalla, área cero), desplaza hacia abajo y reintenta.
 *  fx: punto horizontal del toque (0..1). */
async function tapByLabel(label, { includes = false, fx = 0.5 } = {}) {
  for (let attempt = 0; attempt < 6; attempt++) {
    if (!foreground()) throw new Error('La app dejó el primer plano');
    const xml = dump();
    for (const node of xml.split('<node')) {
      const desc = decode((node.match(/content-desc="([^"]*)"/) ?? [])[1] ?? '');
      const text = decode((node.match(/ text="([^"]*)"/) ?? [])[1] ?? '');
      if (!((includes ? desc.includes(label) : desc.startsWith(label)) || text === label)) continue;
      const [x1, y1, x2, y2] = node.match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/).slice(1).map(Number);
      if (x2 - x1 <= 0 || y2 - y1 <= 0) break; // existe pero no está visible: desplazar
      adb('shell', 'input', 'tap', String(Math.round(x1 + (x2 - x1) * fx)), String((y1 + y2) >> 1));
      await sleep(2500);
      return;
    }
    adb('shell', 'input', 'swipe', '540', '1700', '540', '900', '400');
    await sleep(1200);
  }
  throw new Error(`no encontré "${label}" en pantalla`);
}

/** Recorre la pantalla desplazando hasta que el contenido deja de cambiar. */
async function collect(max = 25) {
  const seen = new Set();
  let prev = '';
  for (let i = 0; i < max; i++) {
    const xml = dump();
    texts(xml).forEach((t) => seen.add(t));
    if (xml === prev) break;
    prev = xml;
    adb('shell', 'input', 'swipe', '540', '1900', '540', '900', '400');
    await sleep(1200);
  }
  return [...seen].join('\n');
}
/** Vuelve al dashboard sin pasarse (nunca pulsa "atrás" estando en el dashboard). */
async function backToDashboard() {
  for (let i = 0; i < 5; i++) {
    if (!foreground()) throw new Error('La app dejó el primer plano');
    if (texts(dump()).some((t) => t.startsWith('Mis Cuentas ('))) {
      adb('shell', 'input', 'swipe', '540', '700', '540', '2000', '300');
      await sleep(800);
      return;
    }
    adb('shell', 'input', 'keyevent', '4');
    await sleep(1500);
  }
  throw new Error('No pude volver al dashboard');
}

// ---------- Comparación ----------
const rows = [];
function check(screen, what, expected, screenText) {
  rows.push({ screen, what, expected, ok: screenText.includes(expected) });
}

if (!foreground()) throw new Error('La app no está en primer plano: abrila con la sesión iniciada y volvé a correr.');

// Dashboard
const balances = await get('/accounts/balances');
let s = await collect();
// Un total por moneda (todas las cuentas tildadas), sin conversión.
for (const t of balances.totals) check('Dashboard', `total ${t.currency}`, money(t.balanceCents, t.currency), s);
for (const a of balances.accounts) {
  check('Dashboard', `saldo ${a.name}`, money(a.balanceCents, a.currency), s);
}
check('Dashboard', 'cantidad de cuentas', `Mis Cuentas (${balances.accounts.length})`, s);
adb('shell', 'input', 'swipe', '540', '700', '540', '2000', '300');
await sleep(800);
adb('shell', 'input', 'swipe', '540', '700', '540', '2000', '300');
await sleep(800);

// Presupuestos
const budgets = await get('/budgets');
await tapByLabel('Límites y Presupuestos', { includes: true, fx: 0.75 });
s = await collect();
for (const b of budgets) {
  const name = b.categories.map((c) => c.name).sort().join(', ');
  check('Presupuestos', `% ${name}`, b.percent == null ? '—' : percent(b.percent), s);
  // Cada límite en la moneda de sus cuentas (los que mezclan monedas, como antes: en pesos).
  const cur = b.currency ?? 'ARS';
  check('Presupuestos', `consumo/límite ${name}`, `${money(b.consumedCents, cur)} / ${money(b.limitCents, cur)}`, s);
}
// Totales de vigentes: uno por moneda (los que mezclan monedas no suman).
const vig = budgets.filter((b) => !b.dueForRenewal && b.currency);
for (const cur of [...new Set(vig.map((b) => b.currency))]) {
  const of = vig.filter((b) => b.currency === cur);
  check('Presupuestos', `total topes vigentes ${cur}`, money(of.reduce((a, b) => a + b.limitCents, 0), cur), s);
  check('Presupuestos', `total gastado vigentes ${cur}`, money(of.reduce((a, b) => a + b.consumedCents, 0), cur), s);
  check('Presupuestos', `total restante vigentes ${cur}`, money(of.reduce((a, b) => a + b.remainingCents, 0), cur), s);
}
await backToDashboard();

// Campana: novedades esperadas según GET /budgets con la regla de la web (percent, dueForRenewal;
// sin límites que todavía no empezaron). Todas deben aparecer y ninguna otra.
const hoy = new Date(Date.now() - 3 * 3600 * 1000).toISOString().slice(0, 10);
const esperadas = [];
for (const b of budgets) {
  if (b.startDate > hoy) continue;
  const titulo = b.categories.map((c) => c.name).sort().join(', ');
  const p = Math.floor(b.percent ?? 0);
  if (b.dueForRenewal) esperadas.push(`El límite '${titulo}' ha finalizado y está vencido`);
  else if (b.percent != null && b.percent >= 100) esperadas.push(`Límite '${titulo}' alcanzado (${p}%)`);
  else if (b.percent != null && b.percent >= 75) esperadas.push(`Límite '${titulo}' cercano al tope (${p}%)`);
}
await tapByLabel('Novedades');
s = await collect(6);
for (const e of esperadas) check('Campana', e, e, s);
const enPantalla = s.split('\n').filter((t) => /^(El límite '|Límite ')/.test(t) && /(vencido|alcanzado|cercano al tope)/.test(t));
const sobrantes = enPantalla.filter((t) => !esperadas.some((e) => t.includes(e)));
check('Campana', 'sin novedades de más', 'ninguna', sobrantes.length ? sobrantes.join(' | ') : 'ninguna');
adb('shell', 'input', 'keyevent', '4');
await sleep(1200);
await backToDashboard();

// Historial
const movs = await get('/movements?limit=20');
await tapByLabel('Historial');
s = await collect(12);
check('Historial', 'resumen', `Últimos ${movs.total} movimientos`, s);
for (const m of movs.items.slice(0, 20)) {
  const cur = m.details[0]?.currency ?? 'ARS';
  check('Historial', `importe #${m.id} ${m.generalConcept ?? ''}`.trim(), money(m.amountCents, cur), s);
}
await backToDashboard();

// Cuentas (Ajustes → Cuentas y Medios de Pago)
const accounts = await get('/accounts');
await tapByLabel('Ajustes y Configuración');
await tapByLabel('Cuentas y Medios de Pago');
s = await collect();
for (const a of accounts) check('Cuentas', `saldo ${a.name}${a.active ? '' : ' (inactiva)'}`, money(a.balanceCents, a.currency), s);
await backToDashboard();

// Reportes: gasto por categoría del mes actual
const now = new Date();
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const from = iso(new Date(now.getFullYear(), now.getMonth(), 1));
const to = iso(new Date(now.getFullYear(), now.getMonth() + 1, 0));
const byCat = await get(`/reports/by-category?from=${from}&to=${to}`);
await tapByLabel('Reportes y Analíticas');
s = await collect(10);
check('Reportes', 'total del mes por categoría', money(byCat.totalCents), s);
for (const i of byCat.items) check('Reportes', `categoría ${i.label}`, money(i.amountCents), s);
await backToDashboard();

// Se revoca la sesión que abrió este script (solo en el modo con credenciales).
if (login) await fetch(`${api}/auth/logout`, { method: 'POST', headers: H, body: JSON.stringify({ refreshToken: login.refreshToken }) });

// ---------- Resultado ----------
const pad = (t, n) => (t.length > n ? t.slice(0, n - 1) + '…' : t.padEnd(n));
console.log(`${pad('Pantalla', 13)} ${pad('Dato', 44)} ${pad('Esperado (API)', 22)} Resultado`);
for (const r of rows) console.log(`${pad(r.screen, 13)} ${pad(r.what, 44)} ${pad(r.expected, 22)} ${r.ok ? 'OK' : 'FALLA (no aparece en pantalla)'}`);
const bad = rows.filter((r) => !r.ok).length;
console.log(`\n${rows.length - bad} OK, ${bad} FALLA`);
process.exit(bad ? 1 : 0);
