#!/usr/bin/env node
// Proxy HTTP para probar cortes de red durante el push (solo servidor de PRUEBAS).
// Escucha en LISTEN (el puerto que ve el celular) y reenvía a UPSTREAM (la API).
// Con --cut-push N: las primeras N peticiones POST /sync/push llegan al servidor, se espera
// su respuesta COMPLETA (el servidor ya aplicó y registró las operaciones) y se corta la
// conexión del celular sin entregársela: el peor caso para duplicados.
//
// Uso:  node tools/net_cut_proxy.mjs [--listen 0.0.0.0:3000] [--upstream 127.0.0.1:3002] [--cut-push 1]
import http from 'node:http';

const arg = (name, def) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : def;
};
const [lhost, lport] = arg('listen', '0.0.0.0:3000').split(':');
const [uhost, uport] = arg('upstream', '127.0.0.1:3002').split(':');
let cutsLeft = Number(arg('cut-push', '0'));
const log = (m) => console.log(`${new Date().toISOString()} ${m}`);

http
  .createServer((req, res) => {
    const isPush = req.method === 'POST' && req.url.endsWith('/sync/push');
    const cut = isPush && cutsLeft > 0;
    if (cut) cutsLeft--;
    const up = http.request({ host: uhost, port: uport, method: req.method, path: req.url, headers: req.headers }, (ur) => {
      if (!cut) {
        res.writeHead(ur.statusCode, ur.headers);
        ur.pipe(res);
        log(`${req.method} ${req.url} → ${ur.statusCode}`);
        return;
      }
      const chunks = [];
      ur.on('data', (c) => chunks.push(c));
      ur.on('end', () => {
        const body = Buffer.concat(chunks).toString();
        let summary = body.slice(0, 300);
        try {
          summary = JSON.parse(body).results.map((r) => `${r.opId}:${r.status}`).join(', ');
        } catch {}
        log(`CORTE: el servidor respondió ${ur.statusCode} [${summary}] y NO se entrega al celular`);
        req.socket.destroy();
      });
    });
    up.on('error', (e) => {
      log(`upstream error: ${e.message}`);
      res.destroy();
    });
    req.pipe(up);
  })
  .listen(Number(lport), lhost, () => log(`proxy ${lhost}:${lport} → ${uhost}:${uport} (cortes de push restantes: ${cutsLeft})`));
