import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../data/tickets_repository.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/network/server_reachability.dart';

/// La dirección del ticket digital (http/https, sin espacios) o null si el QR no es uno.
@visibleForTesting
String? qrUrl(String raw) {
  final url = raw.trim();
  return url.startsWith('http://') || url.startsWith('https://') ? url : null;
}

/// El primer código con contenido de una captura.
@visibleForTesting
String? primerCodigo(List<Barcode> barcodes) =>
    barcodes.map((b) => b.rawValue).firstWhere((code) => code != null && code.isNotEmpty, orElse: () => null);

/// El servidor descarga y analiza el ticket: sin conexión no se puede leer; si no, el motivo con su código.
@visibleForTesting
String motivoFalloQr(Object e, AppLocalizations l) {
  return ServerReachability.isOfflineError(e) ? l.qrNeedsConnection : ErrorMessages.withCode(e, l);
}

@visibleForTesting
String errorDeCamara(MobileScannerErrorCode code, AppLocalizations l) => switch (code) {
      MobileScannerErrorCode.permissionDenied => l.cameraPermissionDenied,
      MobileScannerErrorCode.unsupported => l.cameraUnsupported,
      _ => l.cameraError,
    };

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _procesarQrDetectado(String rawUrl) async {
    if (_isProcessing) return;
    final url = qrUrl(rawUrl);
    if (url == null) {
      AppFeedback.selection();
      AppFeedback.showError(context, context.l10n.scannedQrCodeNotValid);
      return;
    }
    setState(() {
      _isProcessing = true;
      _processingMessage = context.l10n.loadingExpenses;
    });
    try {
      await _controller.stop();
      // El servidor descarga y analiza el ticket (solo con conexión).
      final qr = await ref.read(ticketsRepositoryProvider).parseUrl(url);
      if (!mounted) return;
      AppFeedback.showSuccess(context, context.l10n.receiptReadItemsLines(qr.items.length));
      context.pop(TicketParseResult.fromQr(qr, url));
    } catch (e) {
      debugPrint('[TICKET] No se pudo leer el QR: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _mostrarDialogoFalloQr(motivoFalloQr(e, context.l10n));
      await _controller.start();
    }
  }

  void _mostrarDialogoFalloQr(String motivo) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppColors.rose),
            const SizedBox(width: 10),
            Text(context.l10n.couldNotProcessQr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          context.l10n.motivoDoYouWantScan(motivo),
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.pop(); // Volver a pantalla de fotos
                  },
                  child: Text(context.l10n.usePhotos, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: Text(context.l10n.retry, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final titulo = context.l10n.scanTicketQr;
    final instruccion = context.l10n.pointCameraReceiptQrCode;
    final avisoPrivacidad = context.l10n.ifMerchantNewPageText;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Escáner de QR
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    errorDeCamara(error.errorCode, context.l10n),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              onDetect: (capture) {
                final code = primerCodigo(capture.barcodes);
                if (code != null) _procesarQrDetectado(code);
              },
            ),

            // 2. Overlay informativo y aviso de privacidad
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            instruccion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      avisoPrivacidad,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de carga durante aprendizaje con Gemini AI
            if (_isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          _processingMessage,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _isProcessing = false);
                            _controller.start();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rose,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(context.l10n.cancel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. Botón Cancelar Inferior
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        context.l10n.cancel,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
