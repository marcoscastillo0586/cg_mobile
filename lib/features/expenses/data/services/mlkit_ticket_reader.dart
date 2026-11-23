import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'receipt_spatial_parser.dart';

class MlKitTicketReader implements TicketReader {
  @override
  String get readerName => 'mlkit';

  /// Lee cada foto con ML Kit (sólo en el celular) y arma el resultado con [resultFrom].
  @override
  Future<TicketParseResult> processTicketImages(List<String> imagePaths) async {
    final log = StringBuffer();
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final texts = <RecognizedText>[];
    try {
      for (final path in imagePaths) {
        texts.add(await textRecognizer.processImage(InputImage.fromFilePath(path)));
      }
      return resultFrom(texts, imagePaths, log);
    } catch (e, stack) {
      _log(log, '[TICKET-DEBUG] Error en Google ML Kit / Spatial Parser: $e\n$stack');
      rethrow;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Cada foto se lee por separado con [ReceiptSpatialParser]: se juntan sus renglones y vale el último total
  /// impreso que se haya leído. El registro de diagnóstico lleva las líneas crudas de cada foto.
  @visibleForTesting
  static TicketParseResult resultFrom(List<RecognizedText> texts, List<String> imagePaths, StringBuffer log) {
    _log(log, '========================================');
    _log(log, '[TICKET-DEBUG] captura realizada con Google ML Kit');
    _log(log, '========================================');
    final items = <ParsedTicketItem>[];
    int? total;
    for (final (i, text) in texts.indexed) {
      _logLines(log, i + 1, text);
      final spatial = ReceiptSpatialParser.parseRecognizedText(text);
      if ((spatial.totalDetectadoCents ?? 0) > 0) total = spatial.totalDetectadoCents;
      items.addAll([for (final it in spatial.items) ParsedTicketItem(nombre: it.descripcion, precioCents: it.montoNeto)]);
    }
    _log(log, '========================================');
    _log(log, '[PROCESO DETENIDO] - Datos del ticket procesados geométricamente con receipt_spatial_parser.dart');
    _log(log, '========================================');
    return TicketParseResult(
      readerName: 'mlkit_spatial_parser',
      items: items,
      totalDetectadoCents: total,
      rawTexts: [for (final t in texts) t.text],
      imagePaths: imagePaths,
      diagnosticLog: log.toString(),
    );
  }

  static void _logLines(StringBuffer log, int foto, RecognizedText text) {
    final lines = [for (final b in text.blocks) ...b.lines];
    _log(log, 'Foto #$foto - Líneas raw detectadas por Google ML Kit (Total: ${lines.length}):');
    _log(log, '');
    for (final (i, line) in lines.indexed) {
      final box = line.boundingBox;
      _log(log, 'Línea #${(i + 1).toString().padLeft(2, '0')} [L: ${box.left.toInt()}, T: ${box.top.toInt()}, R: ${box.right.toInt()}, B: ${box.bottom.toInt()}]: "${line.text.trim()}"');
    }
    _log(log, '');
  }

  static void _log(StringBuffer log, String msg) {
    debugPrint(msg);
    log.writeln(msg);
  }
}
