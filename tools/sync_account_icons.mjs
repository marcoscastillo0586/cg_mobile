#!/usr/bin/env node
// Lleva a la app el catálogo de íconos de cuentas: copia las imágenes de la web a assets/account_icons/
// y genera lib/core/widgets/account_icon_catalog.dart. Ejecutarlo cuando cambie el catálogo.
//
// Uso:  node tools/sync_account_icons.mjs [ruta del repo cg]          (por defecto ../cg)
//       node tools/sync_account_icons.mjs [ruta del repo cg] --check  (no escribe; falla si la app quedó desactualizada)
// Requiere @cg/shared compilado en el repo cg: npm run build -w @cg/shared
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const check = args.includes('--check');
const cgRoot = resolve(args.find((a) => a !== '--check') ?? join(appRoot, '..', 'cg'));

const { ACCOUNT_ICONS, DEFAULT_ACCOUNT_ICON } = createRequire(import.meta.url)(join(cgRoot, 'packages/shared/dist/account-icons.js'));
const sourceDir = join(cgRoot, 'apps/web/public/iconos');
const assetDir = join(appRoot, 'assets/account_icons');
const dartFile = join(appRoot, 'lib/core/widgets/account_icon_catalog.dart');

const entries = ACCOUNT_ICONS.map(
  (i) => `  AccountIconEntry(key: '${i.key}', asset: 'assets/account_icons/${i.file}', order: ${i.order}, level: AccountIconLevel.${i.level}),`,
).join('\n');
const dart = `// GENERADO por tools/sync_account_icons.mjs desde @cg/shared. No editar a mano.
enum AccountIconLevel { free, subscription }

class AccountIconEntry {
  final String key;
  final String asset;
  final int order;
  final AccountIconLevel level;

  const AccountIconEntry({required this.key, required this.asset, required this.order, required this.level});
}

const defaultAccountIconKey = '${DEFAULT_ACCOUNT_ICON}';

const accountIconCatalog = <AccountIconEntry>[
${entries}
];
`;

const problems = [];
const expected = new Set(ACCOUNT_ICONS.map((i) => i.file));
for (const { file } of ACCOUNT_ICONS) {
  const source = join(sourceDir, file);
  if (!existsSync(source)) throw new Error(`Falta la imagen ${source}`);
  const target = join(assetDir, file);
  const same = existsSync(target) && readFileSync(source).equals(readFileSync(target));
  if (same) continue;
  if (check) {
    problems.push(`imagen desactualizada: ${file}`);
  } else {
    mkdirSync(assetDir, { recursive: true });
    copyFileSync(source, target);
  }
}
const currentDart = existsSync(dartFile) ? readFileSync(dartFile, 'utf8') : null;
if (currentDart !== dart) {
  if (check) problems.push('catálogo Dart desactualizado');
  else writeFileSync(dartFile, dart);
}
// Las imágenes que ya no están en el catálogo solo se informan: nunca se borran solas.
const extras = existsSync(assetDir) ? readdirSync(assetDir).filter((f) => !expected.has(f)) : [];
if (extras.length) console.warn(`Archivos fuera del catálogo en assets/account_icons: ${extras.join(', ')}`);

if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}
console.log(check ? `Catálogo al día (${ACCOUNT_ICONS.length} íconos).` : `Sincronizados ${ACCOUNT_ICONS.length} íconos.`);
