import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/tickets_repository.dart';
import '../../domain/entities/ticket_parse_result.dart';

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

    final trimmedUrl = rawUrl.trim();
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      AppFeedback.selection();
      if (mounted) {
        AppFeedback.showError(
          context,
          'El código QR escaneado no es una dirección web válida (http/https).',
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Cargando gastos...';
    });

    try {
      await _controller.stop();
      // El servidor descarga y analiza el ticket (solo con conexión).
      final qr = await ref.read(ticketsRepositoryProvider).parseUrl(trimmedUrl);
      if (!mounted) return;
      final result = TicketParseResult(
        readerName: qr.reader,
        items: [
          for (final i in qr.items) ParsedTicketItem(nombre: i.description, precioCents: i.netCents, esDudoso: i.doubtful),
        ],
        totalDetectadoCents: qr.totalPrintedCents,
        rawTexts: [trimmedUrl],
        imagePaths: const [],
        qr: qr,
      );
      AppFeedback.showSuccess(context, 'Ticket leído: ${qr.items.length} renglones');
      context.pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        debugPrint('[TICKET] No se pudo leer el QR: $e');
        _mostrarDialogoFalloQr(ErrorMessages.describe(e, isEn: false) + (ErrorMessages.codeOf(e) != null ? ' (${ErrorMessages.codeOf(e)})' : ''));
        await _controller.start();
      }
    }
  }

  void _mostrarDialogoFalloQr(String motivo) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.rose),
            SizedBox(width: 10),
            Text('No se pudo procesar QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$motivo\n\n¿Deseas intentar reescanear el QR o usar la lectura por fotos?',
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
                  child: const Text('Usar fotos', style: TextStyle(fontSize: 12)),
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
                  child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
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
    final settings = ref.watch(settingsProvider);
    final isEn = settings.language == 'en';

    final titulo = isEn ? 'Scan Ticket QR' : 'Escanear QR del Ticket';
    final instruccion = isEn
        ? 'Point camera at receipt QR code'
        : 'Apuntá la cámara al código QR del ticket';
    final avisoPrivacidad = isEn
        ? 'If this merchant is new, the page text will be sent to an external AI service to learn its reading rules.'
        : 'Si este comercio es nuevo, el texto de la página se enviará a un servicio externo para aprender sus reglas.';

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
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null && code.isNotEmpty) {
                    _procesarQrDetectado(code);
                    break;
                  }
                }
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
                          isEn ? 'Learning this merchant...' : _processingMessage,
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
                          label: Text(isEn ? 'Cancel' : 'Cancelar'),
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
                        isEn ? 'Cancel' : 'Cancelar',
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
