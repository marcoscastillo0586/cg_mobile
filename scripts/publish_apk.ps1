<#
  Publica una version nueva de la app en la PC de casa para que los celulares se actualicen solos
  (la app lee downloads/version.json al abrir; ver lib/core/update/app_updater.dart).

  Pasos: sube el numero de build de pubspec.yaml (+1), arma el APK de release para arm64 firmado con
  android/key.properties, lo copia a la carpeta de descargas de Apache y escribe version.json.

  Uso (desde la raiz del proyecto):
    powershell -ExecutionPolicy Bypass -File scripts\publish_apk.ps1 -Changelog "Que cambio"
  O con las novedades en un archivo UTF-8: -ChangelogFile novedades.txt
  Opcional: -VersionName 1.1.0 (si no, se mantiene la de pubspec), -ApiBaseUrl, -DownloadsDir, -PublicBase.
#>
param(
    [string]$Changelog,
    # Archivo UTF-8 con las novedades (conserva acentos aunque el script se llame desde otra consola).
    [string]$ChangelogFile,
    [string]$VersionName,
    [string]$ApiBaseUrl = 'http://192.168.0.50:3000/api/v1',
    [string]$DownloadsDir = 'C:\xampp\htdocs\downloads',
    [string]$PublicBase = 'http://192.168.0.50/downloads'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pubspec = Join-Path $root 'pubspec.yaml'
$utf8 = New-Object System.Text.UTF8Encoding $false
if ($ChangelogFile) { $Changelog = [IO.File]::ReadAllText((Resolve-Path $ChangelogFile), [Text.Encoding]::UTF8).Trim() }
if (-not $Changelog) { throw 'Indicar las novedades con -Changelog "..." o -ChangelogFile archivo.txt' }

if (-not (Test-Path (Join-Path $root 'android\key.properties'))) { throw 'Falta android/key.properties: sin la clave de release el APK no se instala encima.' }
if (-not (Test-Path $DownloadsDir)) { New-Item -ItemType Directory -Path $DownloadsDir | Out-Null }

# 1. Version: nombre+build en pubspec.yaml; el build es el versionCode de Android y debe subir siempre.
$original = [IO.File]::ReadAllText($pubspec)
$m = [regex]::Match($original, '(?m)^version:\s*([0-9A-Za-z.\-]+)\+(\d+)\s*$')
if (-not $m.Success) { throw 'No se encontro "version: X.Y.Z+N" en pubspec.yaml' }
$name = if ($VersionName) { $VersionName } else { $m.Groups[1].Value }
$code = [int]$m.Groups[2].Value + 1
$updated = $original.Substring(0, $m.Index) + "version: $name+$code" + $original.Substring($m.Index + $m.Length)
[IO.File]::WriteAllText($pubspec, $updated, $utf8)
Write-Host "Version $name+$code" -ForegroundColor Cyan

# 2. APK de release con el código de Flutter solo para arm64 (~69 MB en lugar de ~120 MB del universal;
#    algunos plugins igual incluyen sus librerías para otras arquitecturas).
Push-Location $root
try {
    & flutter build apk --release --target-platform android-arm64 "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build fallo (codigo $LASTEXITCODE)" }
} catch {
    [IO.File]::WriteAllText($pubspec, $original, $utf8) # se deja la version como estaba
    throw
} finally {
    Pop-Location
}
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "No se encontro $apk" }

# 3. Copia con el numero en el nombre (evita copias viejas en caches) y borra las publicaciones anteriores.
$fileName = "cg-$code.apk"
Copy-Item $apk (Join-Path $DownloadsDir $fileName) -Force
Get-ChildItem $DownloadsDir -Filter 'cg-*.apk' | Where-Object { $_.Name -ne $fileName } | Remove-Item -Force

# 4. version.json al final (escritura en temporal + reemplazo): el celular nunca ve un APK a medio copiar.
$info = [ordered]@{
    version_code = $code
    version_name = $name
    apk_url      = "$PublicBase/$fileName"
    changelog    = $Changelog
}
$json = $info | ConvertTo-Json
$target = Join-Path $DownloadsDir 'version.json'
$tmp = "$target.tmp"
[IO.File]::WriteAllText($tmp, $json, $utf8)
Move-Item $tmp $target -Force

$sizeMb = [math]::Round((Get-Item (Join-Path $DownloadsDir $fileName)).Length / 1MB, 1)
Write-Host "Publicado $fileName ($sizeMb MB)" -ForegroundColor Green
Write-Host $json
