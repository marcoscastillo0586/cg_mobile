# cg_mobile

App Android (Flutter) para el control de gastos de CG (paquete `io.github.marcoscastillo0586.cg`, nombre visible `control_gastos`): cuentas, egresos, ingresos, transferencias, presupuestos, historial y lectura de tickets.

> **Estado: adaptación en curso a la API nueva de CG (`/api/v1`).**
> Etapas 1 y 2: autenticación y **lectura** contra `/api/v1` (dashboard, cuentas, categorías,
> presupuestos, campana, historial, buscador y reportes), con importes en centavos.
> Todavía no se escribe: alta y edición de movimientos, ABM y tickets muestran
> "Función no disponible por ahora" hasta sus etapas (5 a 9). Sin conexión, las pantallas
> muestran el error; la base local y la sincronización llegan en las etapas 3 y 4.
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

- **HTTP**: solo en debug y solo hacia `192.168.0.50` (`android/app/src/debug/res/xml/network_security_config.xml`). Release y profile exigen HTTPS.
- La firma de release lee `android/key.properties` (no versionado). Si no existe, release se firma con la clave debug: no distribuir ese APK.

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

- **QR**: se lee el código y se envía la URL al servidor.
- **Fotos** (escáner de documentos o galería): lectura **en el dispositivo** con ML Kit y el parser espacial (`receipt_spatial_parser.dart`). No se envía nada a terceros.
- **Lectura con IA**: deshabilitada ("Función no disponible por ahora"). No hay claves de servicios externos en la app.

## Seguridad

- No se versionan secretos, bases de datos ni keystores. El hook `tools/git-hooks/pre-commit` lo bloquea y muestra solo archivo y línea, nunca el valor.
- Tokens en `flutter_secure_storage`.
- Pendiente por etapas (ver auditoría): HTTP solo en debug y solo hacia la LAN, borrado de la base local al cerrar sesión, logs sin datos en release.

## Tests

`flutter test` → 52 pasan y 4 salteados: 2 de alta de egreso, que se reescriben en la etapa 5, y 2 en vivo, que necesitan servidor.

Los tests con datos simulados no prueban red ni persistencia real. Los siguientes **no aportan verificación útil** y se reemplazarán al rehacer cada función:

| Test | Por qué |
|---|---|
| `test/features/expenses/coto_qr_parser_test.dart` | Solo comprueba que exista el HTML de ejemplo |
| `test/widget_test.dart` | Solo verifica que la app se construye |

Sí ejercitan lógica: `session_manager_test` y `auth_repository_test` (servidor simulado), el test en vivo de sesión, `money_test`, `screens_json_test` (pantallas reales con JSON simulado), `reports_repository_test`, parser espacial (`ticket_reader_test`, `multi_photo_ticket_test`), `limits_admin_state_test`, `movement_detail_test`, `offline_database_test` (SQLite real vía ffi) y los 3 tests activos de `expense_form_notifier_test`.
