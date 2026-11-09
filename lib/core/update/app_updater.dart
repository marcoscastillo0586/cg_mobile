import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../network/transport_guard.dart';

/// Versión publicada en la PC de casa (`downloads/version.json`, lo escribe `scripts/publish_apk.ps1`).
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String changelog;
  const UpdateInfo({required this.versionCode, required this.versionName, required this.apkUrl, required this.changelog});

  /// null si el archivo no tiene lo mínimo (código de versión y dirección del APK).
  static UpdateInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = json['version_code'];
    final url = json['apk_url'];
    if (code is! int || url is! String || url.isEmpty) return null;
    return UpdateInfo(
      versionCode: code,
      versionName: json['version_name']?.toString() ?? '$code',
      apkUrl: url,
      changelog: json['changelog']?.toString() ?? '',
    );
  }
}

/// Actualización de la app sin Play Store: compara la versión instalada con la publicada, descarga el
/// APK y abre el instalador del sistema (Android siempre pide confirmar con "Instalar"). Para instalar
/// encima sin perder datos, el APK tiene que estar firmado con la misma clave de release.
class AppUpdater {
  AppUpdater._();

  static const _channel = MethodChannel('cg/app_update');

  /// Se puede fijar al compilar; si no, se usa el mismo host que la API: `http://<host>/downloads/version.json`.
  static const _overrideUrl = String.fromEnvironment('UPDATE_URL');

  static String? get versionUrl {
    if (_overrideUrl.isNotEmpty) return _overrideUrl;
    if (!ApiConfig.isConfigured) return null;
    final api = Uri.tryParse(ApiConfig.requireBaseUrl);
    if (api == null || api.host.isEmpty) return null;
    return Uri(scheme: api.scheme, host: api.host, path: '/downloads/version.json').toString();
  }

  /// Solo en release de Android: un build de debug está firmado con otra clave y no podría instalar el APK.
  static bool get supported => !kDebugMode && !kIsWeb && Platform.isAndroid;

  static Dio _dio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 10),
      // Siempre lo último publicado (ni el celular ni un proxy deben devolver una copia vieja).
      headers: {'Cache-Control': 'no-cache'},
    ));
    dio.interceptors.add(TransportGuard());
    return dio;
  }

  /// Versión instalada (`versionCode` de Android, el número después del `+` en pubspec.yaml).
  static Future<int> installedVersionCode() async => (await _channel.invokeMethod<int>('versionCode')) ?? 0;

  /// La versión publicada si es más nueva que la instalada; null si no hay o no se pudo consultar
  /// (fuera del wifi de casa, servidor apagado): en ese caso no se avisa nada.
  static Future<UpdateInfo?> check() async {
    final url = versionUrl;
    if (!supported || url == null) return null;
    try {
      final res = await _dio().get<dynamic>(url, queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final data = res.data;
      // Apache puede servirlo como texto plano según su configuración.
      final info = UpdateInfo.fromJson(data is String ? jsonDecode(data) : data);
      if (info == null) {
        debugPrint('[UPDATE] version.json sin version_code o apk_url');
        return null;
      }
      final installed = await installedVersionCode();
      debugPrint('[UPDATE] Instalada $installed, publicada ${info.versionCode}');
      return info.versionCode > installed ? info : null;
    } catch (e) {
      debugPrint('[UPDATE] No se pudo consultar la versión publicada: $e');
      return null;
    }
  }

  /// Descarga el APK a la caché (carpeta compartida con el instalador, ver `update_paths.xml`).
  static Future<String> download(UpdateInfo info, {void Function(double? progress)? onProgress, CancelToken? cancelToken}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true); // descargas anteriores
    dir.createSync(recursive: true);
    final path = '${dir.path}/cg-${info.versionCode}.apk';
    final dio = _dio()..options.receiveTimeout = const Duration(seconds: 60);
    await dio.download(
      info.apkUrl,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) => onProgress?.call(total > 0 ? received / total : null),
    );
    return path;
  }

  /// true: se abrió el instalador. false: falta el permiso "Instalar apps desconocidas" (se abrió ese
  /// ajuste); al volver hay que llamar de nuevo.
  static Future<bool> install(String apkPath) async =>
      await _channel.invokeMethod<String>('installApk', {'path': apkPath}) == 'installing';
}
