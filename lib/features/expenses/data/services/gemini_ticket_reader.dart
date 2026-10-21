import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'gemini_ticket_service.dart';

class GeminiTicketReader implements TicketReader {
  final GeminiTicketService _geminiService;

  GeminiTicketReader({required String apiKey, GeminiTicketService? geminiService})
      : _geminiService = geminiService ?? GeminiTicketService(apiKey: apiKey);

  @override
  String get readerName => 'gemini_1.5_flash';

  @override
  Future<TicketParseResult> processTicketImages(List<String> imagePaths) async {
    final List<File> files = imagePaths.map((p) => File(p)).toList();
    final logBuffer = StringBuffer();

    void logMsg(String msg) {
      debugPrint(msg);
      logBuffer.writeln(msg);
    }

    logMsg('[TICKET-DEBUG] [GEMINI-AI] Procesando ${imagePaths.length} foto(s) con Google Gemini 1.5 Flash Vision...');

    try {
      final ticketData = await _geminiService.extractTicketWithGemini(files);

      logMsg('========================================');
      logMsg('[TICKET-DEBUG] [GEMINI-AI] RESULTADO ESTRUCTURADO RECIBIDO:');
      logMsg('Comercio: ${ticketData.comercio?.nombreComercial ?? ticketData.comercio ?? "No detectado"}');
      logMsg('Fecha: ${ticketData.fecha ?? "No detectada"}');
      logMsg('Total Detectado: \$${ticketData.total?.toStringAsFixed(2) ?? "0.00"}');
      logMsg('----------------------------------------');

      final List<ParsedTicketItem> items = [];
      for (final item in ticketData.items) {
        final double precioFinal = item.subtotal > 0
            ? item.subtotal
            : ((item.cantidad * (item.precioUnitario ?? 0.0)) - item.descuento);

        logMsg(' - Renglón: "${item.descripcion}" | Precio Final: \$$precioFinal (Bruto: \$${item.precioUnitario ?? precioFinal} - Desc: \$${item.descuento})');

        items.add(
          ParsedTicketItem(
            nombre: item.descripcion,
            precio: precioFinal,
            esDudoso: false,
          ),
        );
      }
      logMsg('========================================');

      return TicketParseResult(
        readerName: readerName,
        items: items,
        totalDetectado: ticketData.total,
        rawTexts: [ticketData.toJson().toString()],
        imagePaths: imagePaths,
        diagnosticLog: logBuffer.toString(),
      );
    } catch (e, stack) {
      logMsg('[TICKET-DEBUG] [GEMINI-AI] Error en extracción visual con Gemini: $e\n$stack');
      rethrow;
    }
  }
}
