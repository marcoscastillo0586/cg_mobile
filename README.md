# cg_mobile

App Android (Flutter) para el control de gastos de CG (paquete `io.github.marcoscastillo0586.cg`, nombre visible `control_gastos`): cuentas, egresos, ingresos, transferencias, presupuestos, historial y lectura de tickets.

> **Estado: adaptación en curso a la API nueva de CG (`/api/v1`).**
> Hasta la etapa 1, la app sigue hablando con la API PHP vieja (`/gastos2.0/api/...`).
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
flutter run                                 # con un celular conectado por USB
```

Compilar un APK de prueba:

```sh
flutter build apk --debug
# build/app/outputs/flutter-apk/app-debug.apk
```

La firma de release lee `android/key.properties` (no versionado). Si no existe, release se firma con la clave debug: no distribuir ese APK.

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

`flutter test` → 32 pasan, 2 salteados con motivo (alta de egreso sin cuenta preseleccionada; se reescriben en la etapa 5).

Los tests con datos simulados no prueban red ni persistencia real. Los siguientes **no aportan verificación útil** y se reemplazarán al rehacer cada función:

| Test | Por qué |
|---|---|
| `test/core/network/network_config_test.dart` | Compara constantes de IP |
| `test/core/sync/sync_service_test.dart` | Solo prueba `copyWith` de `SyncState`; no ejecuta la sincronización |
| `test/core/sync/background_sync_service_test.dart` | Construye un estado a mano; no ejecuta nada |
| `test/features/auth/offline_auth_test.dart` | Deserializa un JSON |
| `test/features/dashboard/offline_first_dashboard_test.dart` | Arma entidades a mano; no toca la base ni el repositorio |
| `test/features/expenses/coto_qr_parser_test.dart` | Solo comprueba que exista el HTML de ejemplo |
| `test/features/settings/settings_notifier_test.dart` | Valida URLs PHP fijas que desaparecen en la etapa 1 |
| `test/widget_test.dart` | Solo verifica que la app se construye |

Sí ejercitan lógica: analítica (`analytics_state_test`, `product_price_test`), parser espacial (`ticket_reader_test`, `multi_photo_ticket_test`), `limits_admin_state_test`, `movement_detail_test`, `offline_database_test` (SQLite real vía ffi) y los 3 tests activos de `expense_form_notifier_test`.
