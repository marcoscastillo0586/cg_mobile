import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../l10n/l10n.dart';
import '../../data/services/mlkit_ticket_reader.dart';
import '../../data/services/receipt_spatial_parser.dart';

/// Ticket largo: se fotografía por partes, de arriba hacia abajo, repitiendo algunas líneas entre una
/// foto y la siguiente. Cada parte se guarda a resolución completa (cámara propia o galería sin achicar).
/// La captura de una sola foto ([TicketCaptureScreen]) no cambia.
class LongTicketCaptureScreen extends StatefulWidget {
  const LongTicketCaptureScreen({super.key});

  /// Máximo de partes por ticket.
  static const maxParts = 5;

  @override
  State<LongTicketCaptureScreen> createState() => _LongTicketCaptureScreenState();
}

class _LongTicketCaptureScreenState extends State<LongTicketCaptureScreen> {
  final List<String> _parts = [];
  final ImagePicker _picker = ImagePicker();
  var _reading = false;

  bool get _full => _parts.length >= LongTicketCaptureScreen.maxParts;

  @override
  void dispose() {
    // Las fotos son temporales: al salir de la pantalla se borran.
    for (final path in _parts) {
      _deleteFile(path);
    }
    super.dispose();
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      // No bloquea al usuario: el archivo queda en la caché temporal y lo limpia el sistema.
      debugPrint('[TICKET-LARGO] No se pudo borrar el archivo temporal: $e');
    }
  }

  void _avisarMaximo() => AppFeedback.showError(context, context.l10n.longTicketMaxParts(LongTicketCaptureScreen.maxParts));

  Future<void> _addFromCamera() async {
    if (_full) return _avisarMaximo();
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => LongTicketCameraScreen(previousPartPath: _parts.isEmpty ? null : _parts.last)),
    );
    if (path != null && mounted) {
      AppFeedback.selection();
      setState(() => _parts.add(path));
    }
  }

  Future<void> _addFromGallery() async {
    if (_full) return _avisarMaximo();
    try {
      // Sin achicar: la lectura de cada parte necesita la resolución completa.
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        AppFeedback.selection();
        setState(() => _parts.add(image.path));
      }
    } catch (e) {
      debugPrint('[TICKET-LARGO] No se pudo abrir la galería: $e');
      if (mounted) AppFeedback.showError(context, context.l10n.couldNotAccessGalleryCheck);
    }
  }

  /// Descarta la última parte y vuelve a sacarla (alineada con la anterior).
  Future<void> _redoLast() async {
    if (_parts.isEmpty) return;
    AppFeedback.light();
    setState(() => _deleteFile(_parts.removeLast()));
    await _addFromCamera();
  }

  /// Lee cada parte por separado. R2: muestra las filas de cada parte; su unión (R3) todavía no está.
  Future<void> _finish() async {
    if (_parts.isEmpty || _reading) return;
    setState(() => _reading = true);
    AppFeedback.medium();
    try {
      final parts = await MlKitTicketReader().readLongTicketParts(_parts);
      if (!mounted) return;
      setState(() => _reading = false);
      await _showRows(parts);
    } catch (e, st) {
      debugPrint('[TICKET-LARGO] Error en la lectura de las partes: $e\n$st');
      if (mounted) {
        setState(() => _reading = false);
        AppFeedback.showError(context, context.l10n.longTicketReadError(e));
      }
    }
  }

  Future<void> _showRows(List<List<SpatialRow>> parts) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.longTicketRowsTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (i, rows) in parts.indexed) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(l.longTicketPartRows(i + 1, rows.length), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final row in rows) Text(row.fullText, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
              const SizedBox(height: 12),
              Text(l.longTicketMergePending, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).closeButtonLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l.longTicket)),
      body: _reading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(l.readingReceiptDevice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(14),
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
                          l.longTicketHint,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  l.longTicketPartsCount(_parts.length, LongTicketCaptureScreen.maxParts),
                  key: const ValueKey('ticket-largo-contador'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _parts.length,
                    itemBuilder: (context, index) => Card(
                      key: ValueKey(_parts[index]),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(_parts[index]), width: 56, height: 72, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Text(l.longTicketPart(index + 1), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('ticket-largo-agregar'),
                              onPressed: _full ? null : _addFromCamera,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                              label: Text(l.longTicketAddPart, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _full ? null : _addFromGallery,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: Text(l.longTicketAddFromGallery, textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                      if (_parts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('ticket-largo-rehacer'),
                          onPressed: _redoLast,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: Text(l.longTicketRedoLast),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          key: const ValueKey('ticket-largo-terminar'),
                          onPressed: _finish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(l.longTicketFinish, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Cámara para una parte del ticket largo. Desde la segunda parte muestra arriba, semitransparente, la
/// franja inferior de la parte anterior para alinear la superposición. Devuelve la ruta de la foto
/// (resolución completa) o null si se cancela.
class LongTicketCameraScreen extends StatefulWidget {
  final String? previousPartPath;

  const LongTicketCameraScreen({super.key, this.previousPartPath});

  /// Porción inferior de la parte anterior que se muestra encima (aprox. 20–25 % de su altura).
  static const overlayFraction = 0.22;

  @override
  State<LongTicketCameraScreen> createState() => _LongTicketCameraScreenState();
}

class _LongTicketCameraScreenState extends State<LongTicketCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Object? _error;
  var _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// La cámara se libera al salir de la app y se vuelve a abrir al volver (lo pide el plugin).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive && c != null) {
      _controller = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null && _error == null) {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final c = CameraController(back, ResolutionPreset.max, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (e) {
      debugPrint('[TICKET-LARGO] No se pudo abrir la cámara: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _take() async {
    final c = _controller;
    if (c == null || _taking || !c.value.isInitialized) return;
    setState(() => _taking = true);
    try {
      final file = await c.takePicture();
      AppFeedback.medium();
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      debugPrint('[TICKET-LARGO] No se pudo sacar la foto: $e');
      if (mounted) {
        setState(() => _taking = false);
        AppFeedback.showError(context, context.l10n.longTicketCameraError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _controller;
    final previous = widget.previousPartPath;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l.longTicket),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.longTicketCameraError(_error!), style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            )
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: CameraPreview(
                          c,
                          child: previous == null
                              ? null
                              : Align(
                                  alignment: Alignment.topCenter,
                                  child: IgnorePointer(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Franja inferior de la parte anterior, arriba y semitransparente.
                                        Opacity(
                                          opacity: 0.45,
                                          child: ClipRect(
                                            child: Align(
                                              key: const ValueKey('ticket-largo-superposicion'),
                                              alignment: Alignment.bottomCenter,
                                              heightFactor: LongTicketCameraScreen.overlayFraction,
                                              child: Image.file(File(previous), width: double.infinity, fit: BoxFit.fitWidth),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: double.infinity,
                                          color: Colors.black54,
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          child: Text(
                                            l.longTicketAlignHint,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: IconButton(
                          key: const ValueKey('ticket-largo-disparar'),
                          tooltip: l.longTicketTakePhoto,
                          onPressed: _taking ? null : _take,
                          iconSize: 64,
                          color: Colors.white,
                          icon: _taking
                              ? const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(color: Colors.white))
                              : const Icon(Icons.camera_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
