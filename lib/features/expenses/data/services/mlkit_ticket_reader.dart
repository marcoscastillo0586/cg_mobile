import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'receipt_spatial_parser.dart';
import 'ticket_row_merger.dart';

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
    int? totalDetectadoCents;

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
        
        if (spatialResult.totalDetectadoCents != null && spatialResult.totalDetectadoCents! > 0) {
          totalDetectadoCents = spatialResult.totalDetectadoCents;
        }

        for (final spItem in spatialResult.items) {
          itemsAcumulados.add(
            ParsedTicketItem(
              nombre: spItem.descripcion,
              precioCents: spItem.montoNeto,
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
      totalDetectadoCents: totalDetectadoCents,
      rawTexts: rawTexts,
      imagePaths: imagePaths,
      diagnosticLog: logBuffer.toString(),
    );
  }

  /// Ticket largo: las filas ya unidas pasan al parser existente como si fueran una sola captura.
  /// El total es el IMPRESO (null si no se leyó), para que la verificación contra la suma de los
  /// renglones no se compare consigo misma.
  TicketParseResult longTicketResult(TicketMergeResult merged, List<String> partPaths) {
    final spatial = ReceiptSpatialParser.parseFilasUnidas(merged.rows);
    final log = StringBuffer()
      ..writeln('[TICKET-LARGO] ${partPaths.length} partes, ${merged.rows.length} filas unidas')
      ..writeAll([for (final j in merged.joins.skip(1)) '[TICKET-LARGO] Parte ${j.part}: ${j.status.name}, ${j.overlapRows} filas superpuestas\n'])
      ..writeln('[TICKET-LARGO] Renglones: ${spatial.items.length}; total impreso: ${spatial.totalImpresoCents}');
    debugPrint(log.toString());
    return TicketParseResult(
      readerName: 'mlkit_ticket_largo',
      items: [for (final it in spatial.items) ParsedTicketItem(nombre: it.descripcion, precioCents: it.montoNeto)],
      totalDetectadoCents: spatial.totalImpresoCents,
      rawTexts: [merged.rows.map((r) => r.fullText).join('\n')],
      imagePaths: partPaths,
      diagnosticLog: log.toString(),
    );
  }

  /// Ticket largo: lee cada parte POR SEPARADO (foto completa, sin unir imágenes) con el mismo
  /// reconocedor y devuelve sus filas reconstruidas por posición ([ReceiptSpatialParser.filasDeFoto]),
  /// en el orden de las partes. La unión de las partes es aparte.
  Future<List<List<SpatialRow>>> readLongTicketParts(List<String> partPaths) async => [
        for (final (i, path) in partPaths.indexed) await readLongTicketPart(path, i + 1),
      ];

  /// Una parte del ticket largo (se lee apenas se saca, para verificar enseguida si encadena).
  Future<List<SpatialRow>> readLongTicketPart(String path, int partNumber) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(path));
      final rows = ReceiptSpatialParser.filasDeFoto(recognizedText, partNumber);
      debugPrint('[TICKET-LARGO] Parte #$partNumber: ${rows.length} filas');
      for (final row in rows) {
        debugPrint('[TICKET-LARGO]   [${row.index.toString().padLeft(2, '0')}] ${row.fullText}');
      }
      return rows;
    } finally {
      await textRecognizer.close();
    }
  }
}
