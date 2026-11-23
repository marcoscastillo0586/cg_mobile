import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/server_reachability.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../data/services/ticket_capture_devices.dart';
import '../../data/tickets_repository.dart';
import 'qr_scanner_screen.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

class TicketCaptureScreen extends ConsumerStatefulWidget {
  const TicketCaptureScreen({super.key});

  @override
  ConsumerState<TicketCaptureScreen> createState() => _TicketCaptureScreenState();
}

class _TicketCaptureScreenState extends ConsumerState<TicketCaptureScreen> {
  final List<String> _imagePaths = [];
  bool _isProcessing = false;

  /// Lectura de "Escanear" en curso en el servidor (null = ninguna). Permite cancelarla.
  CancelToken? _lecturaServidor;

  TicketCaptureDevices get _devices => ref.read(ticketCaptureDevicesProvider);

  @override
  void dispose() {
    _lecturaServidor?.cancel();
    super.dispose();
  }

  Future<void> _abrirEscanearQr() async {
    final result = await Navigator.of(context).push<TicketParseResult>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (result != null && mounted) context.pop(result);
  }

  /// Escanear: escáner de Google y lectura con IA en el servidor, que devuelve lo mismo que la lectura en el
  /// celular (misma revisión y mismo guardado). Solo con conexión: sin ella, o si la lectura no está disponible,
  /// avisa y no hace nada más. Sin escáner en el celular, se ofrece la galería.
  Future<void> _escanear() async {
    if (await _devices.offline()) {
      if (mounted) AppFeedback.showError(context, context.l10n.scanRequiresConnection);
      return;
    }
    final List<String> images;
    try {
      images = await _devices.scanDocument();
    } catch (e) {
      debugPrint('Error o fallo en Google ML Kit Document Scanner: $e');
      if (!mounted) return;
      AppFeedback.showError(context, context.l10n.scannerNotAvailableDeviceSelect);
      return _seleccionarDeGaleria();
    }
    if (images.isEmpty || !mounted) return;
    AppFeedback.selection();
    await _leerEnServidor(images);
  }

  Future<void> _leerEnServidor(List<String> images) async {
    final token = CancelToken();
    setState(() => _lecturaServidor = token);
    AppFeedback.medium();
    final started = DateTime.now();
    debugPrint('[TICKET] >>> GEMINI: enviando ${images.length} captura(s) al servidor (/tickets/read-images)');
    Object? error;
    TicketParseResult? result;
    try {
      result = await ref.read(ticketsRepositoryProvider).readImages(images, cancelToken: token);
      debugPrint('[TICKET] <<< GEMINI: ${result.items.length} renglón(es) en ${DateTime.now().difference(started).inMilliseconds} ms');
    } catch (e) {
      debugPrint('[TICKET] Lectura en el servidor no disponible: $e');
      error = e;
    }
    // Las capturas de una lectura que no siguió no se agregan a la lista: se borran.
    if (result == null || result.items.isEmpty) images.forEach(_limpiarArchivoTemporal);
    if (!mounted || token.isCancelled) return;
    setState(() => _lecturaServidor = null);
    if (result == null) return AppFeedback.showError(context, _motivoFalloServidor(error!));
    _devolver(result, context.l10n.receiptReadLines(result.items.length));
  }

  /// Sin conexión, servidor inalcanzable, Gemini caído o demorado: requiere conexión. Cualquier otro rechazo (p.
  /// ej. una foto inválida) muestra el motivo.
  String _motivoFalloServidor(Object e) => e is ServerException && !ServerReachability.isOfflineError(e)
      ? context.l10n.couldNotReadReceipt(e.message)
      : context.l10n.scanRequiresConnection;

  /// Lectura con renglones: vuelve al egreso con ellos. Sin renglones, avisa y se queda.
  void _devolver(TicketParseResult result, String exito) {
    if (result.items.isEmpty) return AppFeedback.showError(context, context.l10n.noProductsWereDetectedReceipt);
    AppFeedback.showSuccess(context, exito);
    context.pop(result);
  }

  void _cancelarLecturaServidor() {
    AppFeedback.light();
    _lecturaServidor?.cancel();
    setState(() => _lecturaServidor = null);
  }

  Future<void> _seleccionarDeGaleria() async {
    final List<String> images;
    try {
      images = await _devices.pickImages();
    } catch (e) {
      debugPrint('[TICKET] No se pudo abrir la galería: $e');
      if (mounted) AppFeedback.showError(context, context.l10n.couldNotAccessGalleryCheck);
      return;
    }
    if (images.isEmpty || !mounted) return;
    AppFeedback.selection();
    setState(() => _imagePaths.addAll(images));
    await _leerEnCelular();
  }

  void _eliminarFoto(int index) {
    AppFeedback.light();
    setState(() => _limpiarArchivoTemporal(_imagePaths.removeAt(index)));
  }

  static void _limpiarArchivoTemporal(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      // No bloquea al usuario: el archivo queda en la caché temporal y lo limpia el sistema.
      debugPrint('[TICKET] No se pudo borrar el archivo temporal: $e');
    }
  }

  /// La lectura con IA (Gemini) de fotos de la galería está deshabilitada hasta que exista un endpoint.
  void _avisarIaNoDisponible() => AppFeedback.showError(context, context.l10n.featureNotAvailableNow);

  /// "Finalizar carga": lectura local en el dispositivo (ML Kit + parser espacial).
  Future<void> _leerEnCelular() async {
    setState(() => _isProcessing = true);
    AppFeedback.medium();
    final started = DateTime.now();
    debugPrint('[TICKET] >>> LOCAL: lectura en el celular (ML Kit) de ${_imagePaths.length} foto(s)');
    try {
      final result = await _devices.readLocal(_imagePaths);
      debugPrint('[TICKET] <<< LOCAL: ${result.items.length} renglón(es) en ${DateTime.now().difference(started).inMilliseconds} ms');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _devolver(result, context.l10n.receiptReadDeviceLines(result.items.length));
    } catch (e, st) {
      debugPrint('[TICKET] Error en la lectura local: $e\n$st');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppFeedback.showError(context, context.l10n.couldNotReadReceipt(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanReceipt)),
      body: switch ((_isProcessing, _lecturaServidor)) {
        (true, _) => _Leyendo(titulo: l10n.readingReceiptDevice, detalle: l10n.extractingProductsNetAmountsDiscounts),
        (_, CancelToken()) =>
          _Leyendo(titulo: l10n.readingReceiptServer, detalle: l10n.readingReceiptServerHint, onCancelar: _cancelarLecturaServidor),
        _ => Column(
            children: [
              const _Guia(),
              Expanded(child: _Capturas(paths: _imagePaths, onEliminar: _eliminarFoto)),
              _Acciones(
                hayCapturas: _imagePaths.isNotEmpty,
                onEscanear: _escanear,
                onQr: _abrirEscanearQr,
                onGaleria: _seleccionarDeGaleria,
                onFinalizar: _leerEnCelular,
                onIa: _avisarIaNoDisponible,
              ),
            ],
          ),
      },
    );
  }
}

/// Lectura en curso (en el celular o en el servidor, que se puede cancelar).
class _Leyendo extends StatelessWidget {
  final String titulo;
  final String detalle;
  final VoidCallback? onCancelar;
  const _Leyendo({required this.titulo, required this.detalle, this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final cancelar = onCancelar;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
            if (cancelar != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const ValueKey('cancelar-lectura-servidor'),
                onPressed: cancelar,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(context.l10n.cancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cómo escanear (recorte automático).
class _Guia extends StatelessWidget {
  const _Guia();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.scanReceiptUsingAutoCrop,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fotos de la galería, numeradas y con su botón para quitarlas.
class _Capturas extends StatelessWidget {
  final List<String> paths;
  final void Function(int index) onEliminar;
  const _Capturas({required this.paths, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(context.l10n.noScansAddedYet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(context.l10n.useScanScanQrGallery, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: paths.length,
      itemBuilder: (context, index) => Card(
        key: ValueKey(paths[index]),
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('#${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(paths[index]), width: 50, height: 50, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.l10n.scan(index + 1), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              IconButton(
                key: ValueKey('quitar-captura-$index'),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                onPressed: () => onEliminar(index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escanear, Escanear QR y Galería; con fotos, "Finalizar carga" y "Leer con IA".
class _Acciones extends StatelessWidget {
  final bool hayCapturas;
  final VoidCallback onEscanear;
  final VoidCallback onQr;
  final VoidCallback onGaleria;
  final VoidCallback onFinalizar;
  final VoidCallback onIa;

  const _Acciones({
    required this.hayCapturas,
    required this.onEscanear,
    required this.onQr,
    required this.onGaleria,
    required this.onFinalizar,
    required this.onIa,
  });

  static ButtonStyle _relleno(Color color, double alto) => ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: Size(alto > 50 ? double.infinity : 0, alto),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const etiqueta = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    return BottomActionArea(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEscanear,
                  style: _relleno(AppColors.primary, 48),
                  icon: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: Text(l10n.scan2, style: etiqueta),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onQr,
                  style: _relleno(Colors.amber.shade800, 48),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(l10n.scanQr, style: etiqueta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onGaleria,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: Text(l10n.gallery, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (hayCapturas) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onFinalizar,
              style: _relleno(AppColors.emerald, 52),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(l10n.finishLoading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: onIa, icon: const Icon(Icons.auto_awesome_outlined, size: 18), label: Text(l10n.readAi)),
          ],
        ],
      ),
    );
  }
}
