import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/app_feedback.dart';

class AppUpdateService {
  static const String _versionJsonUrl = 'http://192.168.0.50/downloads/version.json';

  /// Verificación principal de actualizaciones OTA en el servidor local
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool manual = false,
  }) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ),
      );

      debugPrint('[OTA-UPDATE] Comprobando versión con GET en $_versionJsonUrl...');
      final response = await dio.get<Map<String, dynamic>>(_versionJsonUrl);

      if (response.statusCode != 200 || response.data == null) {
        if (manual && context.mounted) {
          AppFeedback.showError(context, 'Servidor no disponible en red local');
        }
        return;
      }

      final data = response.data!;
      final int remoteVersionCode = (data['version_code'] as num?)?.toInt() ?? 1;
      final String remoteVersionName = data['version_name']?.toString() ?? '1.0.1';
      final String apkUrl = data['apk_url']?.toString() ?? 'http://192.168.0.50/downloads/app-release.apk';
      final String changelog = data['changelog']?.toString() ?? 'Mejoras y correcciones generales.';

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      debugPrint('[OTA-UPDATE] Versión instalada: $currentBuildNumber | Versión remota: $remoteVersionCode');

      if (remoteVersionCode > currentBuildNumber) {
        if (context.mounted) {
          _mostrarDialogoNuevaVersion(
            context,
            versionName: remoteVersionName,
            changelog: changelog,
            apkUrl: apkUrl,
          );
        }
      } else if (manual && context.mounted) {
        AppFeedback.showSuccess(
          context,
          'Ya tienes la última versión instalada (v${packageInfo.version})',
        );
      }
    } catch (e) {
      debugPrint('[OTA-UPDATE] Error al comprobar actualización: $e');
      if (manual && context.mounted) {
        AppFeedback.showError(context, 'Servidor no disponible en red local');
      }
    }
  }

  static void _mostrarDialogoNuevaVersion(
    BuildContext context, {
    required String versionName,
    required String changelog,
    required String apkUrl,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nueva versión disponible (v$versionName)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novedades:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              changelog,
              style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Luego'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_descargarEInstalarApk(context, apkUrl: apkUrl));
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _descargarEInstalarApk(
    BuildContext context, {
    required String apkUrl,
  }) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Descargando actualización...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, value, child) {
              final pct = (value * 100).toInt();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: value, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              );
            },
          ),
        ),
      ),
    ));

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/app_update.apk';

      final File oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      final dio = Dio();
      await dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      debugPrint('[OTA-UPDATE] APK descargado exitosamente en: $savePath. Abriendo instalador...');
      final result = await OpenFilex.open(savePath);
      debugPrint('[OTA-UPDATE] Resultado de OpenFilex: ${result.message}');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppFeedback.showError(context, 'Error al descargar la actualización: $e');
      }
    }
  }
}
