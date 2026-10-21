# Auditoría de la app móvil `cg_mobile` frente a la API nueva de CG

Fecha: 2026-10-21 · Alcance: solo lectura (no se modificó código, no se instaló nada, no se llamó a servicios externos ni se escribió en bases de datos).
Ejecutado: `flutter --version`, `flutter analyze`, `flutter test`.

**Etiquetas usadas en todo el documento**
- **[V] VERIFICADO**: lo leí en el código o lo ejecuté.
- **[D] DECLARADO**: lo dice un comentario, un nombre o un documento (`docs/*.md` de CG). No lo comprobé.
- **[S] SUPOSICIÓN**: deducción mía, sin evidencia directa.

Rutas: `lib/...` es `C:\xampp\htdocs\cg_mobile\lib`. `CG:` es `C:\xampp\htdocs\cg`.

---

## 0. Resumen ejecutivo

| Tema | Hallazgo |
|---|---|
| **La app no compila** | [V] `lib/routes/app_router.dart:10` importa `features/expenses/presentation/screens/ticket_capture_screen.dart`, que **no existe** en `cg_mobile` ni en su git. `flutter analyze`: 2 errores. `flutter test`: `widget_test.dart` no carga. |
| Origen de la copia | [V] `cg_mobile/lib` es idéntica, archivo por archivo (hash), a `C:\xampp\htdocs\gastos2.0\mobile\lib`, salvo ese archivo, que sí existe allá (474 líneas). `test/` y `android/` también son iguales. |
| **Secreto en código** | [V] Clave de la API de Gemini fija en `C:\xampp\htdocs\gastos2.0\mobile\lib\features\expenses\presentation\screens\ticket_capture_screen.dart`, **línea 23**. Hay que considerarla expuesta y rotarla. En `cg_mobile` no aparece justamente porque falta ese archivo. |
| **Duplicación de egresos** | [V] `ExpenseRepositoryImpl.createExpense` (`lib/features/expenses/data/repositories/expense_repository_impl.dart:32-59`) guarda primero en SQLite como `pending_create` y después lo envía al servidor. Si el envío funciona, el registro local **queda** `pending_create`, y el siguiente `sync/push` lo vuelve a mandar. El push viejo no es idempotente (sync.md, D26) [D]. Resultado: cada egreso cargado con conexión puede quedar duplicado en el servidor. |
| Errores ocultos | [V] Egreso, edición y borrado de movimientos, renovación de límites y cambio de estado de cuentas o categorías **devuelven éxito aunque falle el servidor** (por ejemplo, `movement_repository_impl.dart:103-118`, que hace `catch (_) { return true; }`). El usuario ve "guardado" y no se guardó. |
| Sincronización | [V] El contrato es el viejo (`/api/sync/push|pull`). No tiene `opId`, `baseVersion`, cursor, eliminados ni remapeo de ids. `runFullSync` informa "Sincronizado con éxito" aunque fallen el push y el pull (`sync_service.dart:469-476`). La tarea de WorkManager no hace nada (`background_sync_service.dart:12-20`). |
| Límites | [V] La lista de límites siempre se **recalcula en el celular** con datos incorrectos: el consumo se toma de `created_at` (fecha de sincronización, no del gasto), suma ingresos, usa `updated_at` como fecha "hasta" y muestra nombres como "Categoría 5" (`limits_local_data_source.dart:11-74`). Los valores correctos del servidor se descartan. |
| Autenticación | [V] Contra `/api/auth/login` del PHP, que acepta cualquier credencial (D1) [D]. No hay refresh. Sin conexión, se inventa un usuario "Usuario Offline" con id 1 (`auth_remote_data_source.dart:81-87`). Al cerrar sesión **no se borra la base SQLite**. |
| Tests | [V] 31 pasan, 8 fallan y 1 archivo no carga. Casi todos verifican constantes o `copyWith`. Ninguno prueba sincronización, red ni repositorios. |
| Recomendación | **Opción B**: proyecto Flutter nuevo, copiando la interfaz y los lectores de tickets que sirven. Razones en §10. |

---

## 1. Inventario

### 1.1 Entorno y build
| Ítem | Valor | Fuente |
|---|---|---|
| Flutter / Dart | 3.47.6 stable / Dart 3.13.5 | [V] `flutter --version` |
| SDK Dart en pubspec | `>=3.2.0 <4.0.0` | [V] `pubspec.yaml:7` |
| Nombre / versión | `gastos_mobile` 1.0.0+2 | [V] `pubspec.yaml:1,4` |
| applicationId / namespace | `com.example.gastos_mobile` (valor de ejemplo, con un TODO sin resolver) | [V] `android/app/build.gradle.kts:17,28` |
| minSdk / target / compile | Los de Flutter, no fijados en el proyecto: 24 / 36 / 36 | [V] build.gradle.kts:31-32 y `FlutterExtension.kt` del SDK |
| Firma release | Lee `android/key.properties` (existe, no está versionado, contenido no leído). **Si no existe, firma release con la clave debug.** | [V] build.gradle.kts:10-14,50-56; `.gitignore` |
| Minify / shrink | Desactivados | [V] build.gradle.kts:57-58 |
| Tráfico HTTP | `android:usesCleartextTraffic="true"` global | [V] `AndroidManifest.xml:14` |
| Permisos | INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, CAMERA, READ_EXTERNAL_STORAGE, READ_MEDIA_IMAGES, **REQUEST_INSTALL_PACKAGES** | [V] `AndroidManifest.xml:2-8` |
| iOS | No hay carpeta `ios/` | [V] listado |
| Repo git | Un solo commit (`4a22572 Primer commit`, 2026-10-20), 207 archivos versionados | [V] `git log`, `git ls-files` |

### 1.2 Paquetes (pubspec)
Versiones resueltas según `flutter analyze` / `pub get` [V]: flutter_riverpod 2.6.1 (hay 3.4.3), go_router 14.8.1 (hay 18.1.1), dio 5.11.1, sqflite 2.4.4+1 + sqflite_common_ffi 2.4.3, flutter_secure_storage 9.2.4 (hay 11.2.0), connectivity_plus 6.1.5 (hay 7.3.2), workmanager ^0.10.10, mobile_scanner 6.0.11 (hay 7.4.2), google_mlkit_text_recognition 0.13.1 (hay 0.17.1), google_mlkit_document_scanner 0.2.1 (hay 0.6.1), camera 0.11.4, image_picker, fl_chart ^1.2.0, google_fonts 6.3.3 (hay 9.0.0), package_info_plus 8.3.1, open_filex 4.7.0, uuid, intl ^0.20.2, equatable, flutter_lints 3.0.2 (hay 6.0.0). En total, 54 paquetes tienen versiones nuevas incompatibles con las restricciones actuales.
- [V] `camera` y `flutter_svg` están declarados pero no se usan en `lib/`. `ReceiptCameraScreen` usa camera pero es código muerto (§7).
- [S] Riverpod 2 a 3 y go_router 14 a 18 son saltos mayores: conviene hacerlos en un proyecto nuevo y no sobre este.

### 1.3 Estructura y patrones
- [V] Estructura por funcionalidad con capas `data/domain/presentation` ("clean architecture" con mucha ceremonia): `lib/core`, `lib/features/{auth,dashboard,expenses,incomes,transfers,movements,accounts_admin,categories_admin,limits_admin,analytics,settings}`, `lib/routes`, `lib/services`. Son 157 archivos Dart (158 con el faltante) y unas 24.000 líneas.
- [V] **Estado**: Riverpod 2 con `StateNotifier` (API heredada, desaconsejada en Riverpod 3).
- [V] **Navegación**: go_router con redirección según `authNotifierProvider` (`app_router.dart:21-108`). 13 rutas.
- [V] **Red**: un `DioClient` (`core/network/dio_client.dart`) con `AuthInterceptor` (Bearer desde secure storage) y `LogInterceptor`. Los endpoints son URLs **absolutas** armadas sobre un `static String baseUrl` mutable (`core/constants/api_endpoints.dart`).
- [V] **Base local**: sqflite, `gastos_offline.db`, versión 1 (§1.6).
- [V] **i18n**: sin ARB ni `l10n`. Hay 32 ternarios `isEn ? '...' : '...'` en 6 archivos; el resto del texto está fijo en español.

### 1.4 Pantallas
| Ruta | Pantalla | Qué hace | Estado |
|---|---|---|---|
| `/` splash | `auth/.../splash_screen.dart` | Llama a `checkAuth` | [V] |
| `/login` | `login_screen.dart` | Usuario y contraseña contra el PHP | [V] |
| `/dashboard` | `dashboard_screen.dart` | Saldo consolidado, tarjetas de cuentas seleccionables, filtro "hasta fecha", campana de novedades, acciones rápidas, sincronización al abrir, chequeo de actualización OTA | [V] |
| `/expenses/create` (+`?edit_id=`) | `create_expense_screen.dart` | Egreso multirrenglón, sugerencia de categoría, botón "escanear ticket"; también edita egresos | [V] |
| `scanTicket` | `ticket_capture_screen.dart` | **FALTA** en cg_mobile. En gastos2.0: escáner ML Kit, galería, QR, Gemini y lectura básica ML Kit | [V] |
| (push interno) | `qr_scanner_screen.dart` | Lee un QR y POSTea la URL a `/api/tickets/qr` del PHP | [V] |
| — | `receipt_camera_screen.dart` | Cámara propia. **No se usa** | [V] |
| `/incomes/create` | `create_income_screen.dart` | Ingreso, solo con conexión | [V] |
| `/transfers/create` | `create_transfer_screen.dart` | Transferencia, solo con conexión | [V] |
| `/movements` (`?id_lugar&nombre`) | `movements_screen.dart` | Historial, buscador, detalle, editar, eliminar | [V] |
| `/accounts` | `accounts_admin_screen.dart` | ABM de cuentas con íconos | [V] |
| `/categories` | `categories_admin_screen.dart` | ABM de categorías | [V] |
| `/limits` | `limits_admin_screen.dart` | ABM de límites, renovar | [V] |
| `/analytics` | `analytics_screen.dart` | Torta por categoría, comparativa mensual, evolución diaria, precios de productos | [V] |
| `/settings` | `settings_screen.dart` | URL del servidor, tema, idioma, moneda por defecto, actualización OTA | [V] |
| diálogo | `onboarding_dialog.dart` | Moneda e idioma en el primer inicio | [V] |

### 1.5 Endpoints que llama la app (todos PHP, sobre `http://<ip>/gastos2.0`)
[V] Tomado de `core/constants/api_endpoints.dart` y de las fuentes de datos. Las respuestas esperan `{success, data}`, y `DioClient._handleResponse` desenvuelve `data` (`dio_client.dart:124-135`).

| # | Método y ruta | Parámetros / cuerpo | Archivo |
|---|---|---|---|
| 1 | POST `/api/auth/login` | `{usuario, password}` → `{token, usuario}` | `auth_remote_data_source.dart:22` |
| 2 | GET `/api/auth/me` | — | `:66` |
| 3 | POST `/api/auth/logout` | — | `:92` |
| 4 | GET `/api/dashboard/saldos` | `?hasta=yyyy-MM-dd` | `dashboard_remote_data_source.dart:17` |
| 5 | GET `/api/dashboard/limites` | — | `:35` |
| 6 | GET `/api/lugares` | `?todos=1/0` | `accounts_admin_remote_data_source.dart:17` |
| 7 | POST `/api/lugares/crear` | `{nombre, tipo_moneda, img:"icon_N"}` | `:32` |
| 8 | POST `/api/lugares/editar` | `{id_lugar, nombre, tipo_moneda, activo}` | `:53` |
| 9 | POST `/api/lugares/cambiar_estado` | `{id_lugar, activo}` | `:76` |
| 10 | POST `/api/lugares/eliminar` | `{id_lugar}` → `{eliminado_fisico, desactivado, mensaje}` | `:91` |
| 11-15 | GET/POST `/api/categorias[/crear|editar|cambiar_estado|eliminar]` | igual que lugares, con `id_categoria`, `nombre`, `activa` | `categories_admin_remote_data_source.dart` |
| 16 | GET `/api/egresos/formulario_data` | → `{lugares, categorias, conceptos}` | `expense_remote_data_source.dart:20`; también se usa en ingresos y transferencias |
| 17 | POST `/api/egresos/crear` | `{id_lugar, fecha, concepto_general, conceptoGeneral, items:[{monto,id_categoria,categoria,concepto}], gasto:[…]}` (campos duplicados) | `:48` |
| 18 | POST `/api/egresos/escanear_qr` | `{qr_data}`. **Código muerto**: `procesarQrTicket` no se llama desde ningún lado | `:80` |
| 19 | POST `/api/egresos/sugerir_categoria` | `{concepto}` → `{id_categoria}` | `:93` |
| 20 | POST `/api/ingresos/crear` | `{id_lugar, monto, concepto, fecha}` | `income_remote_data_source.dart:28` |
| 21 | POST `/api/transferencias/crear` | `{id_lugar_origen, id_lugar_destino, monto, concepto, fecha}` | `transfer_remote_data_source.dart:28` |
| 22-26 | GET `/api/limites`, POST `/crear|editar|renovar|eliminar` | `{desde, hasta, monto_limite, categoria:"1,2", lugar:"3,4"}`, `{id_limite_gasto}` | `limits_admin_remote_data_source.dart` |
| 27 | GET `/api/reportes/gastos_por_categoria` | `desde, hasta, id_lugar, id_categoria` | `analytics_remote_data_source.dart:24` |
| 28 | GET `/api/reportes/comparativa_mensual` | `anio` | `:48` |
| 29 | GET `/api/reportes/evolucion_diaria` | `mes, anio` | `:66` |
| 30 | GET `/api/reportes/precios_productos` | `search, limit` | `:82` |
| 31 | GET `/api/reportes/historial_producto` | `concepto` | `:106` |
| 32 | POST `/api/reportes/comparativa_precios` | `{desde1,hasta1,desde2,hasta2}` | `:119` |
| 33 | GET `/api/movimientos` | `limit, offset, desde, hasta, id_lugar, id_categoria` | `movement_remote_data_source.dart:17` |
| 34 | GET `/api/movimientos/buscar` | `q, desde, hasta, id_lugar` | `:55` |
| 35 | GET `/api/movimientos/detalle` | `id` | `:107` |
| 36 | POST `/api/movimientos/editar` | cuerpo variable según tipo (`id_movimiento_enc, fecha, concepto_general, id_lugar, monto, detalles|items…`) | `:120` |
| 37 | POST `/api/movimientos/eliminar` | `{id}` | `:128` |
| 38 | POST `/api/sync/push` | `{categorias, lugares, limites, movimientos_enc, movimientos_det}` (filas SQLite crudas) | `sync_service.dart:107` |
| 39 | GET `/api/sync/pull` | `since, offset, limit=500` | `:182` |
| 40 | POST `/api/tickets/qr` | `{qr_url}` | `qr_scanner_screen.dart:56` |
| 41 | POST `/api/tickets/leer` | `{filas_texto}` (Ollama). **Código muerto** | `ollama_api_ticket_reader.dart:66` |
| 42 | GET `http://192.168.0.50/downloads/version.json` y descarga del APK | OTA | `services/app_update_service.dart:12,41` |
| 43 | POST `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=…` | imágenes del ticket en base64 | `gemini_ticket_service.dart:110-129` |

[V] La API PHP de `gastos2.0` y la de `control_gastos_modelo` son idénticas (`diff -rq` sin diferencias), así que la matriz de trazabilidad de CG aplica tal cual.
[V] `/api/sync/pull` del PHP **ignora `since`**: solo aparece en un comentario (`Sync.php:113`). Cada pull descarga todo.

### 1.6 Base local (`core/database/app_local_database.dart`)
| Tabla | Columnas | Escribe | Lee |
|---|---|---|---|
| `categorias_local` | id, sync_id (UNIQUE), remote_id, nombre, estado, sync_status, created_at, updated_at | `categories_local_data_source.dart`, `sync_service.dart` (pull) | categorías, formulario de egreso sin conexión |
| `lugares_local` | ídem + tipo_moneda, simbolo_moneda, monto_original, monto_pesos, cotizacion, saldo_actual (REAL), estado, img_url, img_base64 | `accounts_local_data_source.dart`, `expenses_local_data_source.dart:56` (resta el saldo), pull | dashboard sin conexión, formulario |
| `limites_local` | sync_id, remote_id, categoria_sync_id, categoria_remote_id, monto_limite (REAL), periodo, … | `limits_local_data_source.dart`, pull | límites (siempre), novedades |
| `movimiento_enc_local` | sync_id, remote_id, tipo_movimiento, concepto_general, fecha_movimiento, … | egresos, pull | historial sin conexión |
| `movimiento_det_local` | sync_id, remote_id, movimiento_enc_sync_id (FK), lugar_*, categoria_*, concepto, monto (REAL), … | egresos, pull | límites, sugerencia de categoría, historial sin conexión |
| `dashboard_summary_cache` | totales y cotizaciones | **nadie** | **nadie** |

- [V] Versión 1, con `onUpgrade` hacia la 2 que **nunca corre**, porque `_dbVersion = 1` (`:11,56`). El código de "migración" está muerto.
- [V] Montos en `REAL` (float), no en centavos.
- [V] `sync_status`: `synced | pending_create | pending_update | pending_delete`. No existe un estado "rechazado" ni "con error".
- [V] La base **no está cifrada** y **no se borra al cerrar sesión**.

---

## 2. Funciones presentes y su estado

| Función | Dónde | ¿Funciona de punta a punta? | Depende del PHP |
|---|---|---|---|
| **Egresos** | `features/expenses` | [V] Con conexión: guarda en el servidor y además deja una copia `pending_create` que se reenvía en el push (riesgo de duplicado, §0). Sin conexión: guarda local y resta el saldo local. **Siempre informa éxito**, aunque el servidor rechace (`expense_repository_impl.dart:47-58`). No valida fondos ni pide confirmación. | Sí: `egresos/crear`, `formulario_data`, `sugerir_categoria` |
| **Ingresos** | `features/incomes` | [V] Solo con conexión: sin red, la lista de cuentas queda vacía (`income_repository_impl.dart:19-25`). Los errores sí se muestran. | Sí |
| **Transferencias** | `features/transfers` | [V] Solo con conexión. Valida origen distinto de destino y monto > 0. **No valida que sea la misma moneda ni que haya fondos.** | Sí |
| **Historial y buscador** | `features/movements` | [V] Con conexión usa `movimientos` y `buscar`. Sin conexión, la consulta local trae **una fila por renglón**, con "Cuenta #id" y "Categoría #id" como nombres, ignora fechas y no pagina (`expenses_local_data_source.dart:146-232`). La búsqueda sin conexión devuelve la lista sin filtrar (`movement_repository_impl.dart:77-84`). | Sí |
| **Edición de movimientos** | `edit_movement_dialog.dart`; egresos vía `create_expense_screen?edit_id` | [V] Solo con conexión, pero **sin red informa "actualizado"** (`movement_repository_impl.dart:103-109`) y no encola nada. En egresos con varios renglones, el diálogo no muestra los renglones y reenvía los valores originales; el campo "Monto" se ignora. | Sí: `movimientos/editar` |
| **Eliminar movimiento** | `movements_screen.dart:98` | [V] Igual: sin red **informa éxito y no hace nada**. | Sí |
| **Cuentas e íconos** | `features/accounts_admin` | [V] ABM con 9 íconos de Material (`img: "icon_N"`). **Defecto:** `toggleAccountStatus` llama a `updateAccountLocally(nombre: '', tipoMoneda: 1)`, que **borra el nombre y fuerza ARS** en la copia local, incluso en el camino con conexión (`accounts_admin_repository_impl.dart:87-104`). `cacheAccounts` usa `ConflictAlgorithm.replace`: pisa cambios pendientes y borra `img_*` (`accounts_local_data_source.dart:40-64`). | Sí |
| **Categorías** | `features/categories_admin` | [V] Mismo patrón y mismo defecto en `toggleCategoryStatus` (nombre ''). No protege las categorías reservadas. | Sí |
| **Límites** | `features/limits_admin` | [V] ABM con conexión. **Lectura siempre local y mal calculada** (§0). Renovar sin red devuelve `true` sin hacer nada (`limits_admin_repository_impl.dart:91-97`). | Sí |
| **Campana de novedades** | `dashboard/.../novedades_notifier.dart`, `notification_bell_widget.dart` | [V] Calcula "cerca del 75 %", "alcanzado" y "vencido" en el celular sobre los límites locales mal calculados. Guarda "visto" en secure storage, y eso se borra al cerrar sesión. | Indirecto |
| **Dashboard y saldos** | `features/dashboard` | [V] Con conexión: `dashboard/saldos`. Sin conexión: SQLite con **cotización fija de 1000** (`dashboard_repository_impl.dart:57-73`; también en `sync_service.dart:262` y `expenses_local_data_source.dart:123`). Oculta cuentas con saldo 0. Selección parcial de tarjetas: sí. | Sí |
| **Escáner de documentos y OCR** | `ticket_capture_screen.dart` (**falta**), `mlkit_ticket_reader.dart`, `receipt_spatial_parser.dart` | [V] **No compila.** En la copia de gastos2.0 el flujo es: ML Kit Document Scanner o galería → **Gemini directo desde el celular** con la clave fija → si falla, "lectura básica" ML Kit con el parser espacial. | No (Gemini es externo) |
| **Parser espacial** | `receipt_spatial_parser.dart` (533 líneas) | [V] Agrupa los bloques del OCR en filas por coordenada Y. Tiene tests unitarios mínimos (`ticket_reader_test.dart`, que pasa). [S] Es reutilizable como lectura sin conexión. | No |
| **QR (Coto y Gemini que aprende)** | `qr_scanner_screen.dart` | [V] En la app solo se lee el QR y se manda la URL al PHP `/api/tickets/qr`. **El parser de Coto y el aprendizaje con Gemini viven en el servidor PHP**, no en la app. El "test de Coto" (`coto_qr_parser_test.dart`) solo verifica que exista un HTML de ejemplo. | Sí |
| **Lectura con Ollama** | `ollama_*` (3 archivos) | [V] **Código muerto**: no se instancia en `lib/`. Apunta a `http://10.0.2.2:11434` y a `/api/tickets/leer`. Excluida en CG por U7 [D]. | Sí |
| **Sincronización y sin conexión** | `core/sync/*` | [V] Ver §5. En la práctica no funciona de forma confiable. | Sí: contrato viejo |
| **Onboarding e idiomas** | `onboarding_dialog.dart`, `settings_provider.dart` | [V] Elige moneda (ARS, USD, EUR, PEN, CLP, MXN, BRL) e idioma (es, en). La **moneda por defecto no se usa** en ningún cálculo (solo se muestra en ajustes y en el onboarding). El inglés cubre unas 32 cadenas; el resto queda en español. | No |
| Analítica | `features/analytics` | [V] 4 vistas. Con conexión solamente. Según CG, los reportes de precios del PHP "fallan en BD real" (F8.7) [D]. | Sí |
| Actualización OTA | `services/app_update_service.dart` | [V] Descarga un APK por HTTP desde una IP fija y lo abre para instalar. No verifica hash. | Servidor local |

---

## 3. Contra la API nueva (`CG: apps/api`, prefijo `/api/v1`)

Datos generales de la API nueva [V]:
- Prefijo `api/v1` (`bootstrap.ts:18`).
- Respuestas sin envoltorio `{success, data}`: el DTO viene directo. Los errores tienen la forma `{statusCode, code, message, details}` (`all-exceptions.filter.ts`).
- Montos en **centavos enteros** en las respuestas (`balanceCents`, `amountCents`). En la entrada se aceptan string o número con 2 decimales como máximo; un número con más decimales se **rechaza** (`money.ts:20-25`).
- Fechas de entrada `yyyy-mm-dd` o `dd/mm/aaaa`. Fecha del movimiento en `occurredAt`.
- Ids numéricos del servidor más `clientSyncId` opcional (8 a 64 caracteres) en las altas REST, para reintentos idempotentes.
- Monedas: solo `ARS` y `USD` (string, no 1 o 2).
- Access token de 15 minutos. Refresh rotativo de 30 días, en el cuerpo si se envía `X-Client: mobile`.

### 3.1 Tabla de correspondencias

| App (PHP) | API nueva | Diferencias |
|---|---|---|
| POST `auth/login` `{usuario,password}` → `{token, usuario}` | POST `/auth/login` `{email,password}` + header `X-Client: mobile` → `{accessToken, refreshToken, user}` | Login por email. Cambia la respuesta. Bloqueo tras 5 fallos y 10 intentos por minuto. **Hace falta un interceptor de refresh** (no existe). |
| — | POST `/auth/refresh` `{refreshToken}` + `X-Client: mobile` | Nuevo. Rota el token: hay que guardar el nuevo siempre. Si se reutiliza uno viejo, se revoca toda la familia: dos refresh en paralelo cierran la sesión. Requiere un *mutex*. |
| POST `auth/logout` | POST `/auth/logout` `{refreshToken}` + `X-Client` (204) | Requiere el refresh en el cuerpo. |
| GET `auth/me` | GET `/auth/me` | `UserDto` distinto. |
| GET `dashboard/saldos?hasta` | GET `/accounts/balances?until` → `{until, exchangeRate:{name,sellCents,available}, totalArsCents, accounts[]}` | Centavos. La cotización es real y, si falla, vale 1.0 con la leyenda "sin conexión" (no 1000). |
| GET `dashboard/limites`, GET `limites` | GET `/budgets` → `BudgetDto[]` (`consumedCents`, `remainingCents`, `percent`, `dueForRenewal`, `categories[]`, `accounts[]`) | El servidor calcula consumo, porcentaje y vencimiento: **la app debe dejar de calcularlos.** |
| POST `limites/crear` `{desde,hasta,monto_limite,categoria:"1,2",lugar:"3"}` | POST `/budgets` `{startDate,endDate,limit,categoryIds[],accountIds[],clientSyncId?}` | Arrays en lugar de CSV. De 1 a 5 categorías, sin reservadas. |
| POST `limites/editar` | PATCH `/budgets/:id` | |
| POST `limites/renovar` | POST `/budgets/:id/renew` | |
| POST `limites/eliminar` | DELETE `/budgets/:id` | |
| GET `lugares?todos` | GET `/accounts` → `AccountDto[]` | `currency` es string; `imageUrl` e `iconRef` en vez de `img`. |
| POST `lugares/crear` `{nombre,tipo_moneda,img:"icon_N"}` | POST `/accounts` `{name,currency,iconRef?}` | **`iconRef` solo acepta `casa, banco, alcancia, inversiones, tarjeta_debito, tarjeta_credito, playa, plazo_fijo`** (`constants.ts:47`). Los `icon_N` de la app **se rechazan**. Nombre de 3 a 25 caracteres; la app valida máximo 20 y no valida mínimo [V `account_form_dialog.dart:125`]. Nombre duplicado → 409. |
| POST `lugares/editar` | PATCH `/accounts/:id` `{name?,currency?}` | `activo` va por separado. |
| POST `lugares/cambiar_estado` | POST `/accounts/:id/activate` y `/deactivate` | Desactivar **falla si el saldo es mayor que 0** (F1.4). |
| POST `lugares/eliminar` | DELETE `/accounts/:id` → `{physicallyDeleted, deactivated}` | |
| GET `categorias` | GET `/categories?purpose=all|expense|budget|movements` | `role` marca las reservadas. |
| POST `categorias/crear|editar|eliminar|cambiar_estado` | POST `/categories`, PATCH `/:id`, DELETE `/:id`, POST `/:id/activate` | No hay endpoint de "desactivar" aparte; la baja es híbrida. |
| GET `egresos/formulario_data` | GET `/accounts` + GET `/categories?purpose=expense` + GET `/expenses/concepts` | Tres llamadas. |
| POST `egresos/crear` (doble esquema de campos) | POST `/expenses` `{accountId,date,generalConcept,items:[{concept,categoryId,amount}],clientSyncId}` → `MovementCreatedDto` (201, o 200 si es duplicado) | Valida fondos en el servidor (`INSUFFICIENT_FUNDS`). |
| POST `egresos/sugerir_categoria` | GET `/expenses/suggest-category?concept=` → `{categoryId}` | Pasa de POST a GET. Conviene un *debounce* de 500 ms, que la app no tiene [V]. |
| POST `ingresos/crear` | POST `/incomes` `{accountId,date,concept,amount,clientSyncId}` | |
| POST `transferencias/crear` | POST `/transfers` `{fromAccountId,toAccountId,amount,date?,concept?,clientSyncId}` | Solo entre cuentas de la misma moneda (D16) y con fondos. |
| GET `movimientos` (`desde,hasta,id_lugar,id_categoria,limit,offset`) | GET `/movements` (`from,to,accountIds,categoryIds,q,sort,order,limit≤500,offset`) → `{items,total,hasMore,filteredTotalCents}` | Admite varios ids. Sin fechas devuelve los últimos 60. |
| GET `movimientos/buscar?q` | GET `/movements?q=` | Integrado en el listado. |
| GET `movimientos/detalle?id` | GET `/movements/:id` | |
| POST `movimientos/editar` (cuerpo mezclado) | PATCH `/movements/:id` (fecha, concepto, cuenta), PATCH `/movements/details/:id` (concepto, categoría, monto), PATCH `/movements/:id/transfer` | Edición granular. Ninguna edición puede dejar saldo negativo. |
| POST `movimientos/eliminar` | DELETE `/movements/:id`; DELETE `/movements/details/:id` (solo si hay más de un renglón y no es transferencia) | |
| `reportes/gastos_por_categoria` | GET `/reports/by-category` | |
| `reportes/comparativa_mensual?anio` | GET `/reports/monthly?year` | |
| `reportes/evolucion_diaria?mes&anio` | GET `/reports/daily?year&month` | |
| `reportes/precios_productos` | GET `/reports/products?search&limit` | |
| `reportes/historial_producto?concepto` | GET `/reports/product-history?concept|plu` | |
| POST `reportes/comparativa_precios` | GET `/reports/compare-products?from1…` | Pasa de POST a GET y cambia la semántica (PLU). |
| POST `tickets/qr {qr_url}` | POST `/tickets/parse-url {url}` → `ParsedTicketDto`; después POST `/tickets/confirm` | Se confirma con PLU, precio unitario, imagen y auditoría. Protección anti-SSRF y límite de 20 por minuto. |
| POST `sync/push` / GET `sync/pull` | POST `/sync/push`, GET `/sync/pull?cursor&limit` | Protocolo totalmente distinto (§5). |
| POST `tickets/leer` (Ollama) | — | **No existe**: excluido por U7 [D]. |
| Gemini directo desde el celular | — | **La API no tiene endpoint para leer fotos.** Gemini en el servidor se usa solo para aprender parsers desde URL (F3.9). Decisión pendiente (§11). |
| OTA `version.json` | — | Fuera de la API. |

### 3.2 Lo que la app hace y la API nueva no ofrece
1. Lectura de fotos de tickets: Ollama (excluido, U7) y Gemini con imágenes (no existe en el servidor).
2. Cálculo de consumo de límites y de novedades en el celular: la API ya devuelve `consumedCents`, `percent` y `dueForRenewal`. La campana debería derivarse de eso.
3. Monedas EUR, PEN, CLP, MXN y BRL en el onboarding: la API solo maneja ARS y USD.
4. Íconos `icon_0` a `icon_8`: no están en `ACCOUNT_ICON_KEYS`.
5. Sincronización de tickets con PLU, precio unitario e imagen **sin conexión**: el `movement.create` de sync solo admite `concept, categoryRef, amount` (`schemas.ts:350`). Un ticket cargado sin red pierde PLU, lo que afecta F8.6. [S] Hay que decidir si los tickets se confirman solo con conexión.
6. Actualización OTA del APK.

### 3.3 Lo que la API nueva ofrece y la app no usa
Registro (`/auth/register`), refresh, cambio de contraseña, `PATCH /auth/me`, `GET /accounts/:id/funds` (fondos antes de guardar), `/accounts/:id` (detalle), `/budgets/purge-expired`, `/reports/by-concept-in-categories`, `/reports/by-concept`, `/reports/concepts`, `/reports/compare-periods`, `/reports/income-expense`, `/tickets/status`, `/tickets/confirm` (auditoría, PLU, imagen), `/files/:id` (imágenes protegidas de cuentas y productos), `/health`, edición y borrado por renglón, edición de transferencias, `clientSyncId` en las altas REST, ordenamiento del historial, conflictos por `version` en sync.

---

## 4. Contra escritorio (`CG: docs/traceability.md`)

Leyenda: **Sí** = la app lo tiene · **Distinto** = lo tiene con otra regla · **No** = no lo tiene.

| ID | Estado en la app | Archivo / evidencia |
|---|---|---|
| F1.1 Listado de cuentas | Sí (sin `ORDER BY activo DESC`; local ordena por nombre) | `accounts_admin_*` [V] |
| F1.2 Alta con imagen | Distinto: ícono de Material, sin subir imagen | `account_form_dialog.dart:34-72` [V] |
| F1.3 Alta y edición sin archivo, nombre único | Sí en el servidor. Validación local: máximo 20 (API: de 3 a 25) | [V] |
| F1.4 Desactivar con regla de saldo > 0 | Distinto: sin la regla en la app; sin red pierde el nombre | `accounts_admin_repository_impl.dart:78-105` [V] |
| F1.5 Activar | Sí (toggle) | [V] |
| F1.6 Eliminar | Sí | [V] |
| F1.7 Saldo neto, oculta 0 | Sí (lo filtra el repositorio) | `dashboard_repository_impl.dart:33-35` [V] |
| F1.8 Saldo a fecha | Sí (`hasta`) | `dashboard_screen.dart:71-97` [V] |
| F1.9 Cotización blue | Distinto: viene del servidor; sin red vale 1000 | [V] |
| F1.10 Consolidado ARS | Distinto: sin red vale 1000 | [V] |
| F1.11 Selección parcial | Sí | `dashboard_screen.dart:294-306` [V] |
| F1.12 Selector de cuenta | Sí en egreso (`ExpenseAccountSelector`); dropdown en ingreso y transferencia | [V] |
| F2.1 a F2.5 ABM de categorías | Sí (mismo defecto de toggle) | `categories_admin_*` [V] |
| F2.6 Reservadas | **No** | sin referencias en `categories_admin` [V] |
| F2.7 Exclusión de reservadas | Con conexión depende del PHP [D]; **sin conexión no excluye** | `expenses_local_data_source.dart:98-102` [V] |
| F3.1 Egreso multirrenglón | Sí | [V] |
| F3.2 Validación de fondos | **No** (ni en el cliente) | `expense_form_notifier.dart:341-374` [V] |
| F3.3 Confirmación previa | **No** (guarda directo) | `create_expense_screen.dart:88-112` [V] |
| F3.4 Autocompletado | Sí | [V] |
| F3.5 Sugerencia de categoría | Distinto: sin debounce y pisa la categoría elegida por el usuario | `expense_form_notifier.dart:170-225` [V] |
| F3.6 QR / URL de COTO | Sí, vía PHP | `qr_scanner_screen.dart` [V] |
| F3.7 Revisión del ticket | Parcial: renglones editables y aviso de diferencia con el total | [V] |
| F3.8 Guardar ticket con PLU, unitario e imagen | **No**: se guarda como egreso común | [V] |
| F3.9 Parsers aprendidos + Gemini | Lo hace el servidor PHP; en la app, Gemini lee fotos (distinto) | [V] |
| F3.10 Ollama | Código muerto (excluido) | [V] |
| F3.11 Auditoría del ticket | **No** | [V] |
| F4.1 Ingreso | Sí, solo con conexión | [V] |
| F5.1 Transferencia | Sí, solo con conexión | [V] |
| F5.2 Fondos en origen | **No** en el cliente | [V] |
| F5.3 Origen ≠ destino | Sí | `transfer_form_notifier.dart:104` [V] |
| F5.4 Monedas distintas bloqueadas | **No** | [V] |
| F6.1 Alta de límite | Sí (no verifiqué el máximo de 5 categorías en el formulario) [S] | `limit_form_dialog.dart` |
| F6.2 Consumo, resto y % | **Distinto e incorrecto**: lo recalcula localmente | `limits_local_data_source.dart:11-74` [V] |
| F6.3 Vencimiento / renovar | Sí con conexión; sin red finge éxito; "vencido" se calcula con `updated_at` | [V] |
| F6.4 Renovación mensual | La hace el servidor | [V] |
| F6.5 Editar monto | Sí | [V] |
| F6.6 Eliminar | Sí | [V] |
| F6.7 Purga | No (tampoco tiene botón en la web) | [V] |
| F6.8 Tarjetas en el dashboard | **No**: `ExpenseLimitsList` existe pero no se instancia; hay un acceso a la pantalla de límites | [V] |
| F7.1 Historial con filtros | Sí con conexión; sin red, incompleto | [V] |
| F7.2 Ordenamiento | **No** | [V] |
| F7.3 Detalle | Sí | [V] |
| F7.4 / F7.9 Búsqueda | Sí, en el servidor | [V] |
| F7.5 Agrupar por categoría | **No** | [V] |
| F7.6 / F7.10 Edición | Sí con conexión (con los defectos de §2) | [V] |
| F7.7 Eliminar renglón | **No** | [V] |
| F7.8 Eliminar comprobante | Sí | [V] |
| F8.1 Gasto por categoría | Distinto: torta (CG usa barras) | `category_pie_chart.dart` [V] |
| F8.2, F8.3, F8.5 | **No** | [V] |
| F8.4 Comparativa mensual | Sí | [V] |
| F8.6 Inflación por PLU | Distinto (`comparativa_precios`) | [V] |
| F8.7 Reportes extra | Sí: evolución diaria, precios, historial (CG dice que el PHP falla en BD real [D]) | [V] |
| F9.1 Login | Contra el auth inseguro del PHP | [V] |
| F9.2 / F9.3 Push y pull | Contrato viejo | [V] |

### Reglas de negocio nuevas que la app debe respetar
1. **Sin saldo negativo**: egresos y transferencias se rechazan sin fondos, y ninguna edición puede dejar saldo negativo. Cliente: avisar antes de guardar (`/accounts/:id/funds` o el saldo local). Servidor: `INSUFFICIENT_FUNDS`.
2. **Un gasto cargado sin conexión y sin fondos se rechaza al sincronizar** (`rejected`): la app tiene que mostrarlo, permitir corregirlo o descartarlo, y revertir el saldo local.
3. **Categorías reservadas** (`role`: TRANSFER, INCOME, DEFAULT_TICKET): no se pueden editar, borrar ni elegir en egresos o presupuestos (`RESERVED_CATEGORY`).
4. **Transferencias solo entre cuentas de la misma moneda** y como par atómico.
5. Desactivar una cuenta con saldo mayor que 0 está prohibido.
6. Nombres de cuenta de 3 a 25 caracteres, únicos sin distinguir mayúsculas (409). Categorías de hasta 250 caracteres, únicas.
7. Presupuestos: de 1 a 5 categorías sin reservadas, al menos una cuenta, `endDate >= startDate`, límite > 0.
8. Montos positivos con 2 decimales como máximo; el signo lo pone el servidor.
9. Borrar un renglón solo si el comprobante tiene más de uno y no es una transferencia.
10. Historial: solo cuentas activas por defecto; sin fechas, los últimos 60.

---

## 5. Sincronización y modo sin conexión

### 5.1 Qué hay hoy [V]
- **Base local** con `sync_id` UUID y `sync_status` (§1.6).
- **Escrituras sin conexión** reales solo en: egreso (siempre local, más el intento remoto), alta, edición y baja de cuentas, categorías y límites (solo si falla el remoto). Ingresos, transferencias, edición y borrado de movimientos **no** tienen modo sin conexión.
- **Push** (`sync_service.dart:52-154`): manda todas las filas pendientes de las 5 tablas en un único POST, incluidas las filas `pending_delete`, que el PHP no sabe procesar [S]. Marca `synced` solo los `processed_sync_ids` que devuelve el servidor; según `Sync.php:95-108` [V], el PHP solo devuelve los ids de **detalles**, así que categorías, lugares, límites y encabezados quedan pendientes para siempre y se reenvían.
- **Pull** (`:157-442`): descarga todo, porque el PHP ignora `since`. Pagina por cantidad de encabezados. Hace *upsert* por `sync_id`: las filas del servidor llegan como `cat_remote_<id>`, pero lo creado localmente tiene un UUID, de modo que **lo creado sin conexión aparece duplicado** después del pull (la fila UUID y la `*_remote_*`) [V por la lógica de claves]. Las filas locales pendientes no se actualizan con el servidor. **No hay eliminados**: lo borrado en la web nunca se borra en el celular.
- **Orquestación**: ping a `dashboard/saldos` → push → pull, y estado "success" siempre (`:469-476`). Se dispara al abrir el dashboard, al volver la app a primer plano, al detectar Wi-Fi (debounce de 8 s) y a mano. **No hay bloqueo de concurrencia**: pueden correr dos sincronizaciones a la vez (abrir el dashboard y volver a primer plano) [V, no hay *lock*].
- **WorkManager**: registra una tarea cada 15 minutos que **solo hace `debugPrint`** (`background_sync_service.dart:12-20`). `Workmanager().initialize` se llama desde la UI cada vez que se monta el dashboard.
- **Saldo local**: se resta al crear un egreso, pero el pull lo **pisa** con el saldo del servidor solo si la fila está `synced`. La fórmula USD × 1000 es fija.

### 5.2 Por qué falla
1. Doble escritura en egresos, con push no idempotente → duplicados.
2. `processed_sync_ids` incompleto → reenvío infinito de lo que no es detalle.
3. Identidades distintas para lo local (UUID) y lo remoto (`*_remote_id`) → duplicados después del pull y referencias rotas (`lugar_sync_id: 'lug_remote_<id local>'` cuando la cuenta se creó sin conexión: `expenses_local_data_source.dart:43`).
4. Sin eliminados ni versión → el celular diverge de la web para siempre.
5. Éxito informado siempre → el usuario no se entera.
6. Según CG (D3/D26) [D], el `Sync.php` además usa columnas que no existen en la base real.

### 5.3 Qué falta para `docs/sync.md`
| Requisito | Hoy | Falta |
|---|---|---|
| `opId` único por operación | No | Tabla `outbox(opId, entity, action, clientId, ref, baseVersion, data, status, error, created_at)` |
| `clientId` único en altas | Algo parecido (`sync_id`) | Usarlo como `clientId`; no inventar `*_remote_*` |
| Cola ordenada | No: hoy envía el estado de las tablas, no una cola | Una cola de operaciones en orden de creación; reenviar lo que no tenga resultado con el mismo `opId` |
| Push idempotente | No | Manejar `applied`, `duplicate`, `conflict`, `rejected` y `TEMPORARY_ERROR` |
| `baseVersion` | No | Guardar `version` por entidad y enviarla en update y delete |
| Pull con cursor | No (`since` + offset) | Guardar `cursor`; repetir mientras `hasMore` |
| Eliminados | No | Aplicar `deleted[]` por entidad e id |
| Remapeo de ids | No | `clientId → serverId` al recibir `applied`, y actualizar las referencias locales |
| Orden de subida | No | Cuentas y categorías antes que movimientos y presupuestos (el servidor procesa en el orden enviado) |
| Montos | REAL | Centavos enteros (`*_cents INTEGER`) |
| Refresh de token | No | Interceptor con *mutex*; la sincronización en segundo plano también lo necesita |
| Ejecución en segundo plano | Vacía | Callback real de WorkManager con su propio `ProviderContainer`, o quitarlo |

### 5.4 Qué se puede reutilizar
- **Sí, como idea**: `uuid` para ids, `connectivity_plus` y el ciclo de vida como disparadores, la interfaz de `SyncIconButton`.
- **No**: `sync_service.dart` completo, el esquema SQLite (REAL, identidades mixtas, sin outbox ni versión), las fuentes de datos locales (lógica de `cat_remote_*`, el cálculo de límites) y los repositorios con `catch (_) { return true; }`.

---

## 6. Seguridad

| # | Hallazgo | Evidencia | Gravedad |
|---|---|---|---|
| S1 | **Clave de Gemini fija** en el código fuente (copia de gastos2.0). Si se compiló algún APK con ella, la clave está dentro del APK. | `C:\xampp\htdocs\gastos2.0\mobile\lib\features\expenses\presentation\screens\ticket_capture_screen.dart:23` [V] | **Alta**: rotarla |
| S2 | La clave de Gemini viaja **en la URL** (`?key=`), el mismo defecto D24 que CG corrigió en el servidor | `gemini_ticket_service.dart:111` [V] | Media |
| S3 | **Fotos de tickets enviadas a Google desde el celular** (datos personales: comercio, CUIT, montos y, a veces, nombre o tarjeta) y el JSON completo de la respuesta impreso con `debugPrint`, que **también imprime en release** | `gemini_ticket_service.dart:123,152` [V] | Media |
| S4 | Más `debugPrint` sin `kDebugMode`: URL del QR (`qr_scanner_screen.dart:54`), filas del OCR (código muerto de Ollama), errores con mensajes del servidor | [V] | Baja-media |
| S5 | `LogInterceptor(requestHeader: true, requestBody: true, responseBody: true)` registra el **Bearer token**, las contraseñas del login y todos los datos. **Solo en modo debug**: en dio 5.11.1 `_debugPrint` está dentro de un `assert` | `dio_client.dart:32-39`; `dio-5.11.1/lib/src/interceptors/log.dart:180-181` [V] | Baja (solo debug) |
| S6 | **HTTP en texto claro**, con `usesCleartextTraffic="true"` global. Token y contraseña viajan sin cifrar en la LAN | `AndroidManifest.xml:14`; `api_endpoints.dart` [V] | Alta si la API sale de la LAN |
| S7 | **IPs y URLs fijas**: `192.168.0.50`, `10.0.2.2`, `localhost` | `api_endpoints.dart:8-17`, `network_config.dart:7-8`, `settings_provider.dart:64-67,167`, `settings_screen.dart:211-221`, `app_update_service.dart:12,41`, `ollama_ticket_service.dart:43` [V] | Media |
| S8 | **OTA**: descarga un APK por HTTP sin verificar hash y pide `REQUEST_INSTALL_PACKAGES`. [S] Android exige la misma firma para actualizar, pero si el release se firmó con la clave debug (lo que pasa si falta `key.properties`), la protección depende de esa clave local | `app_update_service.dart`; `build.gradle.kts:52-56` [V] | Media |
| S9 | Tokens en `flutter_secure_storage` con `encryptedSharedPreferences: true`: correcto | `secure_storage_service.dart:6-9` [V] | OK |
| S10 | **SQLite sin cifrar** con todo el historial financiero, en el directorio de documentos de la app | `app_local_database.dart:34-35` [V] | Media |
| S11 | **Cerrar sesión**: `clearAll()` borra *todo* el secure storage (token, usuario, **URL del servidor, tema, idioma, onboarding y "vistos" de novedades**), pero **no** la base SQLite. El siguiente usuario del celular ve los datos del anterior (con conexión, hasta que el pull los pise; sin conexión, siempre) | `auth_remote_data_source.dart:90-97` [V] | **Alta** con la API multiusuario |
| S12 | Usuario falso sin conexión (`idUsuario: 1`, `offline@gastos.com`) si hay token pero no se puede validar | `auth_remote_data_source.dart:81-87` [V] | Media |
| S13 | `onUnauthorized` nunca se pasa al `DioClient` del provider: un 401 en mitad de la sesión no cierra sesión ni intenta refresh | `dio_client.dart:8-11,16` [V] | Media |
| S14 | Permisos de más: `READ_EXTERNAL_STORAGE` (obsoleto desde la API 33), `REQUEST_INSTALL_PACKAGES` y `WAKE_LOCK` | `AndroidManifest.xml` [V] | Baja |
| S15 | `key.properties` existe en `android/` (no versionado; contenido no leído) | `android/key.properties` [V] | Informativo |
| S16 | El login PHP acepta cualquier credencial (D1) | `control_gastos_modelo/.../api/Auth.php:17-42` [V] | Se resuelve con la API nueva |

---

## 7. Calidad

**Análisis y tests** [V]
- `flutter analyze`: 2 errores, los dos por el archivo faltante (`app_router.dart:10,64`).
- `flutter test`: **+31 / −9**.
  - `expense_form_notifier_test.dart`: 5 fallan por `Null check operator` en `expense_form_notifier.dart:28` (`_ref = ref!`). El constructor exige un `Ref` que el test no pasa: el test quedó desactualizado.
  - `settings_notifier_test.dart`: 3 fallan (`FakeSecureStorageService` no implementa `getLanguage`).
  - `widget_test.dart`: no compila por el archivo faltante.
- **Tests sin valor real**: `network_config_test` (compara constantes de IP), `sync_service_test` (`copyWith` de `SyncState`), `background_sync_service_test` (construye un estado a mano, no ejecuta nada), `offline_auth_test` (deserializa un JSON), `offline_first_dashboard_test` (arma entidades a mano), `app_update_service_test` (compara `2 > 1`), `coto_qr_parser_test` (solo comprueba que exista un HTML). **Ningún test cubre repositorios, sincronización, red ni la base local real.** Los de analítica, el parser espacial y `offline_database_test` sí ejercitan algo de lógica.

**Código muerto** [V]: `OllamaApiTicketReader`, `OllamaTicketReader`, `OllamaTicketService`, `ReceiptCameraScreen`, `ExpenseFormNotifier.procesarQrTicket` y `ApiEndpoints.escanearQrTicket`, `ExpenseLimitsList`, la tabla `dashboard_summary_cache`, `_upgradeToVersion2`, `NetworkConfig.checkServerConnectivity`/`setCustomServerIp` [S: no encontré llamadas a `setCustomServerIp`], el callback de WorkManager, y `camera` y `flutter_svg` en pubspec.

**Duplicado** [V]: el *ping* a `dashboard/saldos` está en 2 lugares, el desenvolvimiento de `response['data']` en 4, la conversión USD × 1000 en 4, y el mismo patrón de "repositorio remoto con caché y fallback" se repite en 4 módulos con el mismo defecto de `toggle`.

**Textos fijos sin traducción** [V]: casi toda la interfaz. Solo 6 archivos tienen ternarios `isEn`; no hay ARB.

**Desbordes de diseño (overflow)** en `create_expense_screen.dart`:
- [V] Botón final: `Row` con ícono y `Text('Registrar Gasto ($total)')` de 16 en negrita, **sin `Flexible`** (`:488-500`). Con totales grandes o en inglés se desborda.
- [V] Banner de total: `Row(spaceBetween)` con un `Row` y un `Text` de 22 sin `Flexible` (`:416-464`).
- [S] Selector de fecha: `Expanded(flex:4)`, unos 126 dp en un teléfono de 360 dp, contiene padding 20 + ícono 16 + 4 + texto `dd/MM/yyyy` de 13 en negrita + ícono 18, unos 130-135 dp. Desborde probable en pantallas angostas (`:222-271`).
- [V] Se permiten fechas hasta 30 días en el futuro (`:71`, `edit_movement_dialog.dart:108`).

**Otros defectos** [V]: el `RenglonGasto` toma por defecto la primera categoría de la lista (`expense_form_notifier.dart:52`), que puede ser una reservada si se usan los datos locales; la carrera entre `SettingsNotifier.inicializar()` (lee la URL guardada de forma asíncrona) y el primer `checkAuth` (usa la IP por defecto); el modelo de Gemini se llama `gemini-3.8-flash` en la URL y el lector se identifica como `gemini_1.5_flash` [V; que ese modelo exista: no verificado].

**Dependencias**: ver §1.2. Ninguna figura como discontinuada en la salida de `pub get` [V], pero `StateNotifier` está en modo de mantenimiento en Riverpod [D: documentación de Riverpod].

---

## 8. Tamaño del cambio

Conteo sobre los 157 archivos de `lib/` [V] y estimación [S]:

| Capa | Archivos | Cambio necesario |
|---|---|---|
| `core/network` y `core/constants` (cliente, endpoints, errores) | 6 | Reescritura: base `/api/v1`, interceptor de refresh con mutex, `X-Client`, errores `{code,message}` |
| `core/storage` | 1 | Cambios: guardar access y refresh, no borrar ajustes al cerrar sesión |
| `core/database` | 1 | Reescritura: centavos, `clientId`/`serverId`/`version`, outbox, cursor, migraciones reales |
| `core/sync` | 3 | Reescritura total |
| `features/*/data/datasources` (remotas y locales) | 15 | Reescritura (rutas, cuerpos, centavos, ids) |
| `features/*/data/models` | 14 | Reescritura (DTOs nuevos) |
| `features/*/data/repositories` | 10 | Reescritura (fuente local primero, outbox, errores reales) |
| `features/*/domain` (entidades y repositorios) | 30 | Cambios: `double` a `int` centavos, `currency` string, `role`, `version` |
| `features/*/presentation/providers` | 22 | Cambios medianos o grandes (validaciones nuevas, rechazos de sync, quitar cálculos de límites) |
| `features/*/presentation/screens` y `widgets` | 38 | Cambios chicos o medianos (formato de montos, nuevos campos, errores); 2 o 3 con rediseño (límites, edición de movimientos, ticket) |
| `routes`, `services`, `main` | 4 | Chicos (OTA: decidir) |
| `tests` | 17 | Casi todos a rehacer |

**Total estimado**: entre 100 y 120 de los 158 archivos se tocan; unos 55 a 65 son reescrituras de fondo (todo lo de `data/` y `core/`). [S] Es más de la mitad del código, y justamente la mitad con los defectos graves.

---

## 9. Opciones

### Opción A: adaptar `cg_mobile` en su lugar
**Qué se cambia**: recuperar `ticket_capture_screen.dart` (quitando la clave) para que compile; reemplazar `core/network`, `core/database`, `core/sync`; reescribir las 10 fuentes de datos, los modelos y los repositorios; pasar montos a centavos en dominio y presentación; arreglar los tests; quitar código muerto.
**Orden**: (1) compilar y dejar los tests en verde, (2) cliente y auth nuevos, (3) lecturas, (4) base nueva con migración `onUpgrade`, (5) outbox y sincronización, (6) tickets.
**Riesgos**:
- Convivencia de dos contratos en el mismo código durante la transición.
- La base vieja instalada en celulares: hay que migrarla o tirarla, y tiene datos inconsistentes (duplicados, `*_remote_*`).
- Defectos ocultos por los `catch (_)` que siguen en pie mientras no se reescriba todo.
- Ningún test útil como red de seguridad.
- Riverpod 2 y go_router 14 quedan atrasados o hay que migrarlos en caliente.
- El historial git aporta poco (un solo commit).

### Opción B: proyecto Flutter nuevo e independiente
Carpeta y repositorio propios fuera de `htdocs` (por ejemplo `C:\dev\cg_mobile2`), con `applicationId` propio (por ejemplo `ar.<tuyo>.cg`), Riverpod 3 y go_router actual.
**Qué se copia (adaptado)**:
- `core/theme`, `core/constants/app_colors.dart`, `core/widgets` (skeletons, shimmer), `core/utils/app_feedback.dart`, `date_utils`, `currency_utils` (adaptado a centavos).
- Widgets de presentación: `account_card`, `balance_card`, `quick_actions_bar`, `renglon_gasto_card`, `expense_account_selector`, `movement_card`, `movement_summary_banner`, los gráficos (`category_pie_chart`, `monthly_bar_chart`, `daily_line_chart`), `product_price_tracker_view`, `novedades_bottom_sheet`, `notification_bell_widget`, `onboarding_dialog`.
- `receipt_spatial_parser.dart` y `mlkit_ticket_reader.dart` (lectura local sin red), `qr_scanner_screen.dart` (cambiando el destino a `/tickets/parse-url`), la estructura visual de `ticket_capture_screen.dart` (de la copia de gastos2.0, **sin la clave**).
- Fixtures: `test/fixtures` (fotos y HTML de Coto).
**Qué se rehace**: cliente HTTP y auth, base local, outbox y sincronización, todas las fuentes de datos, modelos y repositorios, los notifiers (con reglas nuevas), i18n con ARB, tests.
**Riesgos**: más trabajo inicial de armado (proyecto, flavors, firma); hay que reconstruir pantallas sobre los widgets copiados; durante un tiempo hay dos apps (el `applicationId` distinto permite tenerlas lado a lado, lo que es una ventaja para comparar).

---

## 10. Recomendación

**Opción B.** Razones:
1. Lo que hay que cambiar (red, base, sincronización, datos y dominio en centavos) es justo lo que está mal, y supera la mitad del código (§8). Lo que funciona bien es interfaz y lectura de tickets, y eso se copia en pocas horas.
2. La app actual no compila y sus tests no protegen nada: "adaptar en su lugar" no tiene red de seguridad.
3. La base local instalada tiene datos inconsistentes (duplicados, identidades mixtas). Un proyecto con otro `applicationId` arranca con una base limpia y un pull completo desde la API nueva, sin migrar basura.
4. Permite subir de una vez a Riverpod 3 y go_router actual, en lugar de arrastrar `StateNotifier`.
5. La app vieja puede seguir instalada como referencia mientras tanto. [S] Ojo: si se sigue usando contra el PHP, puede seguir duplicando egresos.

## 11. Decisiones que necesito de vos

1. **Clave de Gemini**: ¿la rotás ya? (recomendado: sí, ya está en un archivo fuente y quizá en APKs).
2. **Lectura de fotos de tickets**: (a) solo ML Kit en el celular, con el parser espacial y sin IA; (b) un endpoint nuevo en la API que llame a Gemini desde el servidor con la clave en `.env` (requiere ampliar CG); (c) Gemini directo desde el celular con una clave que pone el usuario. Recomiendo (a) para empezar y (b) más adelante.
3. **Tickets sin conexión**: ¿se aceptan con pérdida de PLU, precio unitario e imagen (sync solo admite concepto, categoría y monto), o el ticket se confirma solo con conexión vía `/tickets/confirm`? Recomiendo solo con conexión.
4. **Alcance sin conexión**: ¿qué operaciones deben funcionar sin red? Propuesta: egreso manual, ingreso y transferencia; ABM de cuentas, categorías y presupuestos solo con conexión al principio.
5. **Íconos de cuentas**: ¿adoptar los 8 `iconRef` de la API (`casa`, `banco`, …) y abandonar `icon_0` a `icon_8`?
6. **Monedas**: ¿quitar EUR, PEN, CLP, MXN y BRL del onboarding? (la API solo tiene ARS y USD).
7. **Actualización OTA**: ¿se mantiene (con HTTPS y hash) o se elimina?
8. **Servidor y transporte**: ¿la API nueva va a estar solo en la LAN o publicada? Define si se permite HTTP (solo con `network_security_config` para la IP de la LAN) o HTTPS obligatorio.
9. **Ubicación y nombre** del proyecto nuevo y su `applicationId`.
10. **Idiomas**: ¿se mantiene inglés? Si sí, migrar a ARB desde el inicio.
11. **Datos del dispositivo**: ¿cifrar la base local (por ejemplo, SQLCipher) o alcanza con borrarla al cerrar sesión?

## 12. Plan por etapas (cada una verificable por separado)

| # | Etapa | Contenido | Verificación con evidencia real |
|---|---|---|---|
| 0 | Esqueleto | Proyecto nuevo, Riverpod 3, go_router, flavors con URL por `--dart-define`, `applicationId` propio, firma release, `network_security_config` | `flutter analyze` sin advertencias; `flutter build apk --debug` OK; APK instalado y abre |
| 1 | Autenticación y cliente | Dio con base `/api/v1`, `X-Client: mobile`, access en memoria, refresh en secure storage, interceptor con mutex y reintento, logout que revoca y borra todo | Test de integración contra la API local (base de prueba): login, esperar a que venza el access (TTL corto en `.env` de test), una llamada que refresca sola; dos llamadas paralelas con el access vencido → **un solo** refresh (log del servidor y tabla de refresh tokens); logout → refresh revocado (consulta a la base de test) |
| 2 | Lectura de datos | Cuentas, saldos, categorías, presupuestos, historial y reportes (solo lectura, con conexión), montos en centavos | Comparar pantalla a pantalla contra la web de CG con el mismo usuario: saldos, totales y porcentaje de presupuestos idénticos (capturas lado a lado, y un test que compare JSON de la API con lo que muestra el widget) |
| 3 | Base local | SQLite con `server_id`, `client_id`, `version`, `*_cents`, tablas `outbox` y `sync_state(cursor)`, migraciones versionadas | Tests unitarios con `sqflite_common_ffi`: crear, migrar de v1 a v2 y leer; inspección del `.db` con `sqlite3` |
| 4 | Pull | Descarga completa y por cursor, `hasMore`, `deleted`, upsert por id | Contra la API local con los datos migrados: Σ de `balanceCents` local = `totalArsCents` de `/accounts/balances`; conteo de comprobantes local = `total` de `/movements` con rango completo; borrar un movimiento en la web → desaparece del celular tras el pull |
| 5 | Carga sin conexión | Egreso, ingreso y transferencia escritos en local y en el outbox; validaciones locales (fondos estimados, reservadas, misma moneda) | Modo avión: cargar 3 operaciones, cerrar y abrir la app → siguen en la outbox con su `opId` (query al `.db`) |
| 6 | Push | Envío ordenado; manejo de `applied`, `duplicate`, `conflict`, `rejected` y `TEMPORARY_ERROR`; remapeo `clientId → serverId`; pantalla de "pendientes y rechazados" | (a) Cortar la red a mitad del push y reintentar → en el servidor hay **una** fila por `opId` (consulta a `sync_operations` y a movimientos); (b) gasto sin fondos cargado sin conexión → `rejected INSUFFICIENT_FUNDS` visible y saldo local revertido; (c) editar lo mismo en la web y en el celular con `baseVersion` → `conflict` resuelto según la regla elegida; tests de `apps/api/test/sync.spec.ts` como referencia de casos |
| 7 | Edición y borrado | PATCH de encabezado, renglón y transferencia; DELETE de renglón y comprobante (con y sin conexión vía sync) | Editar un monto que dejaría saldo negativo → rechazo visible; borrar un renglón único → bloqueado en la UI; auditoría en `audit_log` |
| 8 | ABM y presupuestos | Cuentas (íconos `iconRef`), categorías (reservadas bloqueadas), presupuestos (sin cálculos locales), campana a partir de `percent` y `dueForRenewal` | Desactivar una cuenta con saldo → error de la API mostrado; la campana muestra lo mismo que las tarjetas de la web |
| 9 | Escáner, QR y OCR | QR → `/tickets/parse-url` → revisión → `/tickets/confirm`; ML Kit + parser espacial como lectura local; (opcional) Gemini según la decisión 2 | Ticket real de COTO (el mismo de `scripts/ticket-probe.ts`): 62 renglones y diferencia de 0,01 con el total; fila en `tickets` con PLU e imagen; fotos de `test/fixtures/fotos` → renglones detectados (test con valores esperados) |
| 10 | Endurecer | Sin `debugPrint` de datos en release, R8/minify, permisos mínimos, borrado al cerrar sesión, i18n | `flutter build apk --release` + `apkanalyzer` (permisos), `adb logcat` durante un flujo completo sin tokens ni contenido de tickets; un segundo usuario en el mismo celular no ve datos del primero |
