import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'app_updater.dart';

/// Consulta una vez por apertura de la app si hay una versión nueva publicada y, si la hay, la ofrece.
class UpdatePrompt {
  UpdatePrompt._();

  static bool _checked = false;

  static Future<void> checkOnce(BuildContext context) async {
    if (_checked || !AppUpdater.supported) return;
    _checked = true;
    final info = await AppUpdater.check();
    if (info == null || !context.mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => UpdateDialog(info: info));
  }
}

/// "Hay una actualización": novedades, descarga con progreso y apertura del instalador del sistema.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  CancelToken? _descarga;
  double? _progreso;
  String? _apk;
  String? _aviso;

  bool get _descargando => _descarga != null;

  @override
  void dispose() {
    _descarga?.cancel();
    super.dispose();
  }

  Future<void> _actualizar() async {
    final l10n = context.l10n;
    setState(() => _aviso = null);
    var apk = _apk;
    if (apk == null) {
      final token = CancelToken();
      setState(() {
        _descarga = token;
        _progreso = null;
      });
      try {
        apk = await AppUpdater.download(widget.info, cancelToken: token, onProgress: (p) {
          if (mounted) setState(() => _progreso = p);
        });
        _apk = apk;
      } catch (e) {
        debugPrint('[UPDATE] Falló la descarga: $e');
        if (mounted && !token.isCancelled) setState(() => _aviso = l10n.updateDownloadFailed);
        return;
      } finally {
        if (mounted) setState(() => _descarga = null);
      }
    }
    if (!mounted) return;
    try {
      if (await AppUpdater.install(apk)) {
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _aviso = l10n.updateNeedsPermission);
      }
    } catch (e) {
      debugPrint('[UPDATE] No se pudo abrir el instalador: $e');
      if (mounted) setState(() => _aviso = l10n.updateInstallFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = widget.info;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_descargando,
      child: AlertDialog(
        key: const ValueKey('actualizacion-disponible'),
        icon: const Icon(Icons.system_update_rounded),
        title: Text(l10n.updateAvailableTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateAvailableVersion(info.versionName)),
            if (info.changelog.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(info.changelog.trim(), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_descargando) ...[
              const SizedBox(height: 16),
              Text(l10n.updateDownloading),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progreso),
              if (_progreso != null) ...[
                const SizedBox(height: 4),
                Text('${(_progreso! * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
            if (_aviso != null) ...[
              const SizedBox(height: 12),
              Text(_aviso!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _descarga?.cancel();
              Navigator.of(context).pop();
            },
            child: Text(_descargando ? MaterialLocalizations.of(context).cancelButtonLabel : l10n.updateLater),
          ),
          FilledButton(
            onPressed: _descargando ? null : _actualizar,
            child: Text(l10n.updateNow),
          ),
        ],
      ),
    );
  }
}
