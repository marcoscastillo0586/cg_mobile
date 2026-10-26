# cg_mobile

App Android (Flutter) para el control de gastos de CG (paquete `io.github.marcoscastillo0586.cg`, nombre visible `control_gastos`): cuentas, egresos, ingresos, transferencias, presupuestos, historial y lectura de tickets.

> **Estado: adaptación en curso a la API nueva de CG (`/api/v1`).**
> Etapas 1 a 10: sesión, base local (SQLite) con outbox y sincronización, altas, ediciones, ABM,
> límites, tickets (QR por el servidor; fotos con ML Kit en el celular),
> endurecimiento de release e idiomas español/inglés.
> El plan por etapas y el diagnóstico de partida están en [docs/auditoria_mobile.md](docs/auditoria_mobile.md).

## Requisitos

- Flutter 3.47.6 (Dart 3.13.5) — versión con la que se verificó.
- Android SDK con build-tools 36. Solo Android: no hay carpeta `ios/`.

## Primeros pasos

```sh
flutter pub get
git config core.hooksPath tools/git-hooks   # activa el hook anti-secretos (una vez por clon)
flutter analyze
flutter test
```

La dirección de la API **no está en el código**: se fija al compilar.

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.0.50:3000/api/v1
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.0.50:3000/api/v1
```

Sin `API_BASE_URL`, el login muestra "La app no tiene configurada la dirección del servidor".

- **HTTP**: solo hacia `192.168.0.50` (la PC de casa, IP fija), en debug y en release; cualquier otro host exige HTTPS
  (`INSECURE_TRANSPORT`). Lo controla `TransportGuard` (`lib/core/network/transport_guard.dart`) en todas las peticiones:
  el cliente HTTP de Dart **no** aplica `network_security_config` (verificado con un APK release). Sin HTTPS, la contraseña
  y los datos viajan sin cifrar por el wifi de casa, y la app solo funciona conectada a esa red.
- **Release**: R8 (minify y shrink, `android/app/proguard-rules.pro`) y sin logs (`debugPrint` vacío en release, `main.dart`).
- **Permisos** del APK final: INTERNET, CAMERA (QR) y ACCESS_NETWORK_STATE (lo agrega `com.google.android.datatransport`, de ML Kit).
  La galería usa el selector del sistema y no pide permisos de medios.
- **Idiomas**: español (plantilla) e inglés en `lib/l10n/app_*.arb` (`flutter gen-l10n`; se usa `context.l10n`). Las validaciones
  hechas en el celular usan `ValidationFailure.t((l) => l.clave)`; los errores de la API se traducen por código en `ErrorMessages`.
- La firma de release lee `android/key.properties` (no versionado; el `.jks` vive fuera del repo). Sin ese archivo
  **el release no se arma** (`Falta android/key.properties…`); debug no lo necesita.

### APK para instalar (release)

Requiere `android/key.properties`. Para la API real en la PC de casa (HTTP, ver arriba):

```sh
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=http://192.168.0.50:3000/api/v1
# Celulares actuales: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (~41 MB; el APK universal pesa ~110 MB)
```

Verificar la firma: `apksigner verify --print-certs <apk>` debe mostrar el certificado propio, no `CN=Android Debug`.
Un APK firmado con otra clave no se instala encima del de debug: hay que desinstalar antes (se borran los
datos locales; lo que ya se sincronizó vuelve a bajar del servidor).

### Servidor de pruebas (PC)

La API de CG escucha en `0.0.0.0:3000` (todas las interfaces). Para pruebas se usa una **copia** de la base (`control_gastos_dev`), nunca `control_gastos`.

Para que el celular llegue a la API, abrir el puerto **solo para la subred local** (PowerShell como administrador):

```powershell
New-NetFirewallRule -DisplayName "CG API 3000 (LAN, pruebas)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000 -RemoteAddress LocalSubnet -Profile Private -InterfaceAlias "Ethernet"
# Ver:    Get-NetFirewallRule -DisplayName "CG API 3000 (LAN, pruebas)"
# Quitar: Remove-NetFirewallRule -DisplayName "CG API 3000 (LAN, pruebas)"
```

### Verificación de pantallas contra la API (celular real)

`tools/verify_screens.mjs` inicia sesión en la API de pruebas, recorre las pantallas del celular por
adb y compara cada saldo, total y porcentaje que se ve con el JSON de la API (misma regla de formato).
La app tiene que estar abierta con la sesión del mismo usuario. Nunca usar contra la base real.

```sh
node tools/verify_screens.mjs http://192.168.0.50:3000/api/v1 <credenciales.json>
```

### Verificación de la sincronización (celular real)

`tools/verify_sync.mjs` copia `cg_local.db` del celular por adb (`run-as`, solo app debug), consulta la API
de pruebas con un token firmado en memoria con el `JWT_ACCESS_SECRET` del servidor de pruebas (sin
contraseñas) y compara filas por tabla, suma de montos, saldo y renglones por cuenta (`GET /accounts`),
la vista `account_balances` (`GET /accounts/balances`) y los comprobantes (`GET /movements`).
Imprime una tabla OK/FALLA; sale con código 1 si hay alguna falla. Requiere Node >= 22.5.

```sh
node tools/verify_sync.mjs http://192.168.0.50:3000/api/v1 <archivo-con-el-secreto> <userId> [cg_local.db]
```

También compara cada límite (consumo, %, vencido, monto, período y vínculos) contra `GET /budgets`.
`tools/verify_screens.mjs` acepta el mismo token de prueba (`<secreto> <userId>`) y compara además la campana.

`GET /movements` solo cuenta comprobantes con renglones; los comprobantes vacíos no entran en esa fila.
Lo cargado en el celular y todavía no enviado (sin `server_id`) se excluye de esas comparaciones; la vista
local se compara contra el saldo del servidor más lo pendiente de cada cuenta.

`tools/outbox_dump.mjs` muestra la outbox y los comprobantes pendientes del celular (sin red ni API):

```sh
node tools/outbox_dump.mjs
```

### Corte de red a mitad del envío

`tools/net_cut_proxy.mjs` se pone entre el celular y la API de pruebas: con `--cut-push N` deja que el
servidor procese los primeros N envíos y corta la conexión antes de entregar la respuesta.

```sh
# API de pruebas en 3002 y el proxy en el puerto que usa el celular (3000)
node tools/net_cut_proxy.mjs --listen 0.0.0.0:3000 --upstream 127.0.0.1:3002 --cut-push 1
```

### Prueba en vivo de la sesión

`test/integration/auth_live_test.dart` usa el código de la app contra una API real (se saltea si faltan las variables):

```sh
CG_LIVE_API=http://192.168.0.50:3000/api/v1 CG_LIVE_TTL=20 CG_LIVE_EMAIL=... CG_LIVE_PASSWORD=...   flutter test test/integration/auth_live_test.dart
```

`CG_LIVE_TTL` debe coincidir con `JWT_ACCESS_TTL_SECONDS` del servidor de pruebas (un valor corto, p. ej. 20).

## Sesión

- Login por email con header `X-Client: mobile` (el servidor devuelve el refresh token en el cuerpo).
- Access token **solo en memoria**; refresh token en el almacenamiento seguro, y siempre se guarda el nuevo antes de usarlo.
- Un **único refresh en vuelo** (`SessionManager`): el servidor revoca toda la familia si se reutiliza un refresh viejo.
- Sin red al abrir la app: se usa el último usuario confirmado por el servidor ("sin conexión"). No hay usuarios inventados.
- **Cerrar sesión** (Ajustes): revoca en el servidor, borra la base local y la sesión, y conserva tema, idioma, moneda y onboarding.
- Ajustes → "Diagnóstico de sesión" (solo debug): 2 llamadas en paralelo y cuántos refresh hubo.

## Base local

`cg_local.db` (sqflite), esquema en `lib/core/database/migrations.dart`:

- Cuentas, categorías, presupuestos, encabezados y renglones con `local_id`, `server_id`, `client_id` (UUID de las altas hechas en el celular), `version` del servidor y eliminado lógico.
- Importes en centavos (`INTEGER` con `CHECK(typeof(...) = 'integer')`): la base rechaza decimales.
- `outbox`: cola de operaciones en orden (`seq`), con `op_id` único, `status` y `error`. `sync_state`: cursor del pull.
- Saldos: vista `account_balances` calculada en vivo (no hay tablas de caché).
- Migraciones numeradas que se aplican en orden; una base de una versión más nueva que la app no se abre.
- Al cerrar sesión se borran `cg_local.db` y el archivo viejo `gastos_offline.db`.
- Altas sin conexión (`lib/features/movements/data/local_movement_writer.dart`): egreso, ingreso y transferencia
  escriben comprobante, renglones y una operación de la outbox (`op_id` y `client_id` UUID) en **una** transacción.
  Validan como el servidor contra el saldo local (que incluye lo pendiente): fondos, categorías reservadas o
  inactivas, cuenta inactiva, misma moneda en transferencias. Los formularios avisan la falta de fondos antes de
  guardar. Cuentas, categorías y sugerencias salen de SQLite.
- Dashboard: saldos calculados de la base local con la regla de `GET /accounts/balances` (no consulta al
  servidor). Sin cotización ni conversión entre monedas: un total por moneda con las cuentas tildadas; el de
  la moneda principal (elegida en el primer ingreso) va grande y el de la otra, si tiene cuentas, más chico.
- Edición y borrado (`lib/features/movements/data/local_movement_editor.dart`, pantalla "Editar comprobante"):
  encabezado (concepto, fecha, cuenta), cada renglón (concepto, categoría, monto; por `serverId`, sin `baseVersion`),
  transferencia como par, borrar renglón (solo si hay más de uno y no es transferencia: `LAST_DETAIL`/`TRANSFER_EDIT`)
  y borrar comprobante. Todo sin conexión por la outbox, con "deshacer" para rechazos y descartes. Saldo: editar
  egresos/ingresos puede dejar una cuenta en negativo (aviso y confirmación); editar una transferencia no puede
  dejar el origen en negativo (`INSUFFICIENT_FUNDS`).
- Cuentas, categorías y límites (`lib/features/*_admin/data/local_*_repository.dart`): alta, edición,
  activar/desactivar y baja sin conexión por la outbox, con las reglas del servidor (nombres únicos,
  `ACCOUNT_HAS_FUNDS`, `CURRENCY_LOCKED`, reservadas protegidas, máx. 5 categorías por límite, `INVALID_PERIOD`).
  Activar/desactivar envía solo `active`. Desactivar una categoría se envía como `category:delete` (mismo efecto
  en el servidor; con `update` el servidor fallaba al borrar una categoría sin uso). El consumo de los límites se
  calcula en SQLite con la regla de budgets.service.ts y la campana se deriva de ese porcentaje y del vencimiento.
- Envío (`lib/core/sync/push_service.dart`): `POST /sync/push` en orden, con `opId` y `clientId` estables
  (un reintento reenvía lo mismo y el servidor responde `duplicate`). `applied`/`duplicate` remapean
  clientId → serverId; `rejected` revierte el cambio local; `TEMPORARY_ERROR` queda pendiente; `conflict`
  aplica la versión del servidor. Lo no aplicado se ve en Ajustes → **Pendientes y rechazados**, donde se
  corrige (reabre el formulario), se descarta (revierte el saldo local) o, en conflicto, se reintenta con los
  cambios propios (`baseVersion` nuevo).
- Un solo sincronizador (`SyncController`): primero envía y después descarga; si quedó algo pendiente por error
  temporal no descarga. Informa "completa" solo si todo se aplicó y coincide con el servidor.
- Descarga (`lib/core/sync/pull_service.dart`): `GET /sync/pull` de a 500 mientras `hasMore`, cada página en
  su transacción con lecturas en bloque y `batch` (4954 comprobantes: 10,6 s en el celular; antes 115 s), upsert por `server_id`, aplica `deleted[]` y, en la descarga completa, borra lo que el servidor
  ya no tiene. Al final compara saldo y cantidad de renglones por cuenta con el servidor: el cursor se guarda
  y la sincronización se marca "completa" solo si todo coincide; si no, se descarta el cursor y se muestran las diferencias.
- Prueba en el dispositivo (SQLite de Android): `flutter test integration_test/local_database_device_test.dart -d <id>`.
  **Reinstala la app y borra sus datos**: no correrla con operaciones pendientes.

## Estructura

```
lib/
  core/        red (Dio), base local (sqflite), sincronización, tema, utilidades
  features/    una carpeta por función, con capas data / domain / presentation
  routes/      go_router
test/          tests unitarios y fixtures (ticket de Coto, fotos de tickets)
tools/         git-hooks/pre-commit
docs/          auditoría y decisiones
```

Estado: Riverpod 2 (`StateNotifier`). Navegación: go_router.

## Lectura de tickets

- **QR** (solo con conexión): `POST /tickets/parse-url` lee el ticket en el servidor; el formulario se precarga
  con fecha, concepto, renglones y la categoría sugerida. Guardar llama a `POST /tickets/confirm` con un
  `clientSyncId` estable (un reintento no duplica el egreso); el comprobante llega con el próximo pull.
- **Fotos** (escáner de documentos o galería): lectura **en el dispositivo** con ML Kit y el parser espacial
  (`receipt_spatial_parser.dart`, importes en centavos enteros) para cargar renglones a revisar. Se guarda como
  un egreso común (outbox). Si la suma no coincide con el total leído, se avisa la diferencia. No se envía nada a terceros.
- **Lectura con IA**: deshabilitada ("Función no disponible por ahora"). No hay claves de servicios externos en la app.

## Seguridad

- No se versionan secretos, bases de datos ni keystores. El hook `tools/git-hooks/pre-commit` lo bloquea y muestra solo archivo y línea, nunca el valor.
- Tokens en `flutter_secure_storage`.
- Cerrar sesión borra la base local y además descarta todo el estado en memoria (`SessionScope`): otro usuario en el mismo
  celular, sin cerrar la app, no ve datos del anterior.

## Tests

`flutter test` → 168 pasan y 2 salteados (en vivo, necesitan servidor).

Los tests con datos simulados no prueban red ni persistencia real. Los siguientes **no aportan verificación útil** y se reemplazarán al rehacer cada función:

| Test | Por qué |
|---|---|
| `test/features/expenses/coto_qr_parser_test.dart` | Solo comprueba que exista el HTML de ejemplo |
| `test/widget_test.dart` | Solo verifica que la app se construye |

Sí ejercitan lógica: `session_manager_test` y `auth_repository_test` (servidor simulado), el test en vivo de sesión, `money_test`, `screens_json_test` (pantallas reales con JSON simulado), `reports_repository_test`, parser espacial (`ticket_reader_test`, `multi_photo_ticket_test`), `limits_admin_state_test`, `movement_detail_test`, `offline_database_test` (SQLite real vía ffi) y los 3 tests activos de `expense_form_notifier_test`.
