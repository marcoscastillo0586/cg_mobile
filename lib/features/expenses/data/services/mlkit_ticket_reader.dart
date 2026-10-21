import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'receipt_spatial_parser.dart';

class RecognizedLineData {
  final String text;
  final Rect box;

  RecognizedLineData({
    required this.text,
    required this.box,
  });

  double get centerY => (box.top + box.bottom) / 2.0;
  double get height => box.height;
}

class MlKitTicketReader implements TicketReader {
  @override
  String get readerName => 'mlkit';

  @override
  Future<TicketParseResult> processTicketImages(List<String> imagePaths) async {
    final logBuffer = StringBuffer();
    void logMsg(String msg) {
      debugPrint(msg);
      logBuffer.writeln(msg);
    }

    logMsg('========================================');
    logMsg('[TICKET-DEBUG] captura realizada con Google ML Kit');
    logMsg('========================================');

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<String> rawTexts = [];
    final List<ParsedTicketItem> itemsAcumulados = [];
    double? totalDetectado;

    int fotoIdx = 0;
    try {
      for (final path in imagePaths) {
        fotoIdx++;
        final inputImage = InputImage.fromFilePath(path);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        rawTexts.add(recognizedText.text);

        final totalLines = recognizedText.blocks.fold(0, (acc, b) => acc + b.lines.length);
        logMsg('Foto #$fotoIdx - Líneas raw detectadas por Google ML Kit (Total: $totalLines):');
        logMsg('');

        int lineNum = 0;
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            lineNum++;
            final text = line.text.trim();
            final box = line.boundingBox;
            logMsg(
              'Línea #${lineNum.toString().padLeft(2, '0')} [L: ${box.left.toInt()}, T: ${box.top.toInt()}, R: ${box.right.toInt()}, B: ${box.bottom.toInt()}]: "$text"',
            );
          }
        }
        logMsg('');

        // Ejecución de la Reconstrucción Espacial Geométrica mediante ReceiptSpatialParser
        final spatialResult = ReceiptSpatialParser.parseRecognizedText(recognizedText);
        
        if (spatialResult.totalDetectado != null && spatialResult.totalDetectado! > 0) {
          totalDetectado = spatialResult.totalDetectado;
        }

        for (final spItem in spatialResult.items) {
          itemsAcumulados.add(
            ParsedTicketItem(
              nombre: spItem.descripcion,
              precio: spItem.montoNeto,
            ),
          );
        }
      }
    } catch (e, stack) {
      logMsg('[TICKET-DEBUG] Error en Google ML Kit / Spatial Parser: $e\n$stack');
      rethrow;
    } finally {
      await textRecognizer.close();
    }

    logMsg('========================================');
    logMsg('[PROCESO DETENIDO] - Datos del ticket procesados geométricamente con receipt_spatial_parser.dart');
    logMsg('========================================');

    return TicketParseResult(
      readerName: 'mlkit_spatial_parser',
      items: itemsAcumulados,
      totalDetectado: totalDetectado,
      rawTexts: rawTexts,
      imagePaths: imagePaths,
      diagnosticLog: logBuffer.toString(),
    );
  }
}
