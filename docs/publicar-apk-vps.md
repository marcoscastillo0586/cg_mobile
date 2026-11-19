# Publicar actualizaciones del APK en el VPS

Servidor de producción: `https://controldegastos.codigo15.com.ar`
La app busca actualizaciones en `https://controldegastos.codigo15.com.ar/downloads/version.json`
y descarga el APK que figura en ese archivo. Android siempre pide confirmar con "Instalar".

---

## A. Configuración inicial en el VPS (una sola vez)

### 1. Bloque de Nginx para `/downloads/`

Agregar dentro del `server { listen 443 ssl; ... }` del sitio, **antes** de `location /`:

```nginx
# Actualizaciones de la app Android: version.json y los .apk.
location /downloads/ {
    root /var/www;
    add_header Cache-Control "no-cache";
}
```

### 2. Carpeta y recarga

```bash
sudo mkdir -p /var/www/downloads
sudo nginx -t && sudo systemctl reload nginx
```

### 3. Comprobar

```bash
curl -i https://controldegastos.codigo15.com.ar/downloads/version.json
```

- Antes de subir archivos: tiene que dar **404 de Nginx**.
- Si devuelve el HTML de la web, el bloque no está tomando: revisar que esté dentro del `server` de 443 y recargar.

---

## B. Publicar una versión nueva (cada vez)

### 1. Compilar en la PC (PowerShell, desde `C:\xampp\htdocs\cg_mobile`)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\publish_apk.ps1 `
  -Changelog "Qué cambió en esta versión" `
  -ApiBaseUrl "https://controldegastos.codigo15.com.ar/api/v1" `
  -DownloadsDir "C:\xampp\htdocs\cg_mobile\build\vps-downloads" `
  -PublicBase "https://controldegastos.codigo15.com.ar/downloads"
```

El script:
- sube el número de build en `pubspec.yaml` (+1),
- compila el APK release firmado con `android/key.properties` (misma clave → se instala encima),
- deja en `build\vps-downloads\` el archivo `cg-<N>.apk` y `version.json`.

> Sin `android/key.properties` (y `C:\Users\marcos\upload-keystore.jks`) no se puede firmar igual:
> el APK no se instalaría encima. Guardar copia de la keystore fuera de la PC.

### 2. Subir al VPS (primero el APK, después version.json)

Desde la PC (reemplazar `usuario@vps` y `<N>`):

```powershell
scp C:\xampp\htdocs\cg_mobile\build\vps-downloads\cg-<N>.apk usuario@vps:/tmp/
scp C:\xampp\htdocs\cg_mobile\build\vps-downloads\version.json usuario@vps:/tmp/
```

En el VPS:

```bash
sudo mv /tmp/cg-<N>.apk /var/www/downloads/
sudo mv /tmp/version.json /var/www/downloads/
# opcional: borrar APKs viejos
ls /var/www/downloads/
sudo rm /var/www/downloads/cg-<N_VIEJO>.apk
```

El orden importa: si `version.json` llega antes que el APK, un celular podría intentar
descargar un archivo que todavía no existe.

### 3. Comprobar

```bash
curl https://controldegastos.codigo15.com.ar/downloads/version.json
curl -I https://controldegastos.codigo15.com.ar/downloads/cg-<N>.apk
```

- El primero devuelve el JSON con `version_code` = `<N>`.
- El segundo da `200` y `Content-Length` ≈ 69 MB.

### 4. En el celular

Abrir la app: avisa que hay versión nueva → Descargar → Instalar.
La primera vez Android puede pedir el permiso "Instalar apps desconocidas" para la app.

---

## Referencia

| Qué | Dónde |
|---|---|
| Script de publicación | `cg_mobile\scripts\publish_apk.ps1` |
| Salida local | `cg_mobile\build\vps-downloads\` (se borra con `flutter clean`) |
| Carpeta pública en el VPS | `/var/www/downloads/` |
| URL de version.json | `https://controldegastos.codigo15.com.ar/downloads/version.json` |
| Lógica del actualizador | `cg_mobile\lib\core\update\app_updater.dart` |
| Clave de firma | `C:\Users\marcos\upload-keystore.jks` (alias `upload`) |
| Certificado SHA-256 esperado | `39d65b1e5d2b0c5324497da26b2c181bff6202e19fb896469add0594f1c50616` |

Notas:
- El APK release solo acepta HTTPS: `apk_url` en `version.json` tiene que empezar con `https://`.
- Si la app no avisa la actualización: el `version_code` publicado debe ser **mayor** que el instalado
  (Ajustes → Aplicaciones → CG → versión) y el celular necesita internet.
