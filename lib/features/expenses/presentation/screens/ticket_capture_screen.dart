import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../data/services/mlkit_ticket_reader.dart';
import 'qr_scanner_screen.dart';
import '../../../../l10n/l10n.dart';

class TicketCaptureScreen extends ConsumerStatefulWidget {
  const TicketCaptureScreen({super.key});

  @override
  ConsumerState<TicketCaptureScreen> createState() => _TicketCaptureScreenState();
}

class _TicketCaptureScreenState extends ConsumerState<TicketCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _imagePaths = [];
  bool _isProcessing = false;

  Future<void> _abrirEscanearQr() async {
    final result = await Navigator.of(context).push<TicketParseResult>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      context.pop(result);
    }
  }

  Future<void> _escanearDocumentoConMlKit() async {
    try {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.base,
        pageLimit: 8,
      );
      final documentScanner = DocumentScanner(options: options);
      final result = await documentScanner.scanDocument();

      if (result.images.isNotEmpty && mounted) {
        AppFeedback.selection();
        setState(() {
          _imagePaths.addAll(result.images);
        });
        await _procesarTicketFinalizarCarga();
      }
    } catch (e) {
      debugPrint('Error o fallo en Google ML Kit Document Scanner: $e');
      if (mounted) {
        AppFeedback.showError(
          context,
          context.l10n.scannerNotAvailableDeviceSelect,
        );
        await _seleccionarDeGaleria();
      }
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (images.isNotEmpty && mounted) {
        AppFeedback.selection();
        setState(() {
          _imagePaths.addAll(images.map((img) => img.path));
        });
        await _procesarTicketFinalizarCarga();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          context.l10n.couldNotAccessGalleryCheck,
        );
      }
    }
  }

  void _eliminarFoto(int index) {
    AppFeedback.light();
    setState(() {
      final path = _imagePaths.removeAt(index);
      _limpiarArchivoTemporal(path);
    });
  }

  void _limpiarArchivoTemporal(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // No bloquea al usuario: el archivo queda en la caché temporal y lo limpia el sistema.
      debugPrint('[TICKET] No se pudo borrar el archivo temporal: $e');
    }
  }


  /// La lectura con IA (Gemini) está deshabilitada hasta que exista un endpoint en el servidor.
  void _avisarIaNoDisponible() {
    AppFeedback.showError(
      context,
      context.l10n.featureNotAvailableNow,
    );
  }

  /// Lectura local en el dispositivo: ML Kit + parser espacial. No envía datos a ningún servidor.
  Future<void> _procesarTicketFinalizarCarga() async {
    if (_imagePaths.isEmpty) {
      AppFeedback.showError(
        context,
        context.l10n.addLeastOnePhotoReceipt,
      );
      return;
    }

    setState(() => _isProcessing = true);
    AppFeedback.medium();

    try {
      final result = await MlKitTicketReader().processTicketImages(_imagePaths);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result.items.isEmpty) {
        AppFeedback.showError(
          context,
          context.l10n.noProductsWereDetectedReceipt,
        );
        return;
      }

      AppFeedback.showSuccess(
        context,
        context.l10n.receiptReadDeviceLines(result.items.length),
      );
      context.pop(result);
    } catch (e, st) {
      debugPrint('[TICKET] Error en la lectura local: $e\n$st');
      if (mounted) {
        setState(() => _isProcessing = false);
        AppFeedback.showError(
          context,
          context.l10n.couldNotReadReceipt(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titulo = context.l10n.scanReceipt;
    final instruccion = context.l10n.scanReceiptUsingAutoCrop;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
      ),
      body: _isProcessing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.readingReceiptDevice,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.extractingProductsNetAmountsDiscounts,
                      style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Banner Guía Estándar Limpio
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instruccion,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Galería de fotos capturadas numeradas
                Expanded(
                  child: _imagePaths.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                size: 54,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.noScansAddedYet,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.useScanScanQrGallery,
                                style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _imagePaths.length,
                          itemBuilder: (context, index) {
                            final path = _imagePaths[index];
                            final numFoto = index + 1;

                            return Card(
                              key: ValueKey(path),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#$numFoto',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(path),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        context.l10n.scan(numFoto),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                                      onPressed: () => _eliminarFoto(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Botones de acción inferiores
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Botón 1: Escanear (Auto-recorte)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _escanearDocumentoConMlKit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.document_scanner_rounded, size: 18),
                              label: Text(
                                context.l10n.scan2,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Botón 2: Escanear QR
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _abrirEscanearQr,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade800,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                              label: Text(
                                context.l10n.scanQr,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Botón 3: Galería
                      OutlinedButton.icon(
                        onPressed: _seleccionarDeGaleria,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: Text(
                          context.l10n.gallery,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_imagePaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _procesarTicketFinalizarCarga,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: Text(
                            context.l10n.finishLoading,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _avisarIaNoDisponible,
                          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                          label: Text(context.l10n.readAi),
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
