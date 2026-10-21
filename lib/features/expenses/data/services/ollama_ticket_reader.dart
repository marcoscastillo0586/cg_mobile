import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'ollama_ticket_service.dart';

class OllamaTicketReader implements TicketReader {
  final OllamaTicketService _ollamaService;

  OllamaTicketReader({OllamaTicketService? ollamaService})
      : _ollamaService = ollamaService ?? OllamaTicketService();

  @override
  String get readerName => 'ollama_qwen2.5vl_7b';

  @override
  Future<TicketParseResult> processTicketImages(List<String> imagePaths) async {
    final List<String> rawTexts = [];
    final List<ParsedTicketItem> items = [];
    double? totalDetectado;

    for (final path in imagePaths) {
      final file = File(path);
      try {
        final ticketData = await _ollamaService.extractTicketData(file);
        rawTexts.add(ticketData.toJson().toString());

        if (ticketData.total != null && ticketData.total! > 0) {
          totalDetectado = ticketData.total;
        }

        for (final item in ticketData.items) {
          items.add(
            ParsedTicketItem(
              nombre: item.descripcion,
              precio: item.subtotal > 0
                  ? item.subtotal
                  : ((item.cantidad * (item.precioUnitario ?? 0.0)) - item.descuento),
              esDudoso: item.precioUnitario == null && item.subtotal <= 0,
              motivoDuda: item.precioUnitario == null
                  ? 'Precio unitario no detectado explícitamente'
                  : null,
            ),
          );
        }
      } catch (e, stack) {
        debugPrint('[OLLAMA-READER] Error procesando imagen con Ollama: $e\n$stack');
        rethrow;
      }
    }

    return TicketParseResult(
      readerName: readerName,
      items: items,
      totalDetectado: totalDetectado,
      rawTexts: rawTexts,
      imagePaths: imagePaths,
    );
  }
}
