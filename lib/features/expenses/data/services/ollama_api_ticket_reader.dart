import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../domain/services/ticket_reader.dart';
import 'mlkit_ticket_reader.dart';
import 'receipt_spatial_parser.dart';

class OllamaApiTicketReader implements TicketReader {
  final DioClient _dioClient;
  final MlKitTicketReader _fallbackReader;

  OllamaApiTicketReader(this._dioClient, [MlKitTicketReader? fallbackReader])
      : _fallbackReader = fallbackReader ?? MlKitTicketReader();

  @override
  String get readerName => 'ollama_qwen2.5vl_7b';

  @override
  Future<TicketParseResult> processTicketImages(List<String> imagePaths) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final logBuffer = StringBuffer();

    void logMsg(String msg) {
      debugPrint(msg);
      logBuffer.writeln(msg);
    }

    logMsg('[TICKET-DEBUG] [FILAS] Reconstrucción espacial en Dart...');

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<RecognizedText> recognizedTexts = [];

    try {
      for (final path in imagePaths) {
        final inputImage = InputImage.fromFilePath(path);
        final recognizedText = await textRecognizer.processImage(inputImage);
        recognizedTexts.add(recognizedText);
      }
    } catch (e) {
      logMsg('[TICKET-DEBUG] Error en ML Kit OCR: $e');
    } finally {
      await textRecognizer.close();
    }

    // Paso 2: Reconstrucción Espacial en Dart
    final List<String> filasTexto = ReceiptSpatialParser.parseMultipleRecognizedTextsToLines(recognizedTexts);

    logMsg('[TICKET-DEBUG] [FILAS] Imprimiendo ${filasTexto.length} filas reconstruidas antes de enviar a Ollama:');
    for (final line in filasTexto) {
      logMsg('[TICKET-DEBUG] [FILAS] $line');
    }

    // Paso 3: Envío a Ollama (POST /api/tickets/leer)
    final payload = {
      'filas_texto': filasTexto,
    };

    try {
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] Enviando filas de texto a Ollama vía API PHP (${ApiEndpoints.baseUrl}/api/tickets/leer)...');

      final response = await _dioClient.post(
        '${ApiEndpoints.baseUrl}/api/tickets/leer',
        data: payload,
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      stopwatch.stop();
      final elapsedSec = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

      final fullJsonStr = jsonEncode(response);
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] === RESPUESTA COMPLETA DE OLLAMA ($elapsedSec s) ===');
      _printInChunks(fullJsonStr, logMsg);

      Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response;
        }
      } else {
        throw Exception('Estructura de respuesta no válida de la API PHP');
      }

      final rawItems = data['items'] as List<dynamic>? ?? [];
      final double? totalDet = (data['total'] as num?)?.toDouble();

      final List<ParsedTicketItem> items = [];
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] ÍTEMS ESTRUCTURADOS RECIBIDOS:');

      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          final desc = it['descripcion']?.toString() ?? 'Producto';
          final mBruto = (it['monto_bruto'] as num?)?.toDouble() ?? 0.0;
          final descVal = (it['descuento'] as num?)?.toDouble() ?? 0.0;
          final mNeto = (it['monto_neto'] as num?)?.toDouble() ?? (mBruto - descVal);

          logMsg(
            '[TICKET-DEBUG] [OLLAMA-JSON] Renglón ${it['renglon']}: "$desc" | Bruto: \$$mBruto | Desc: \$$descVal | Neto: \$$mNeto',
          );

          items.add(
            ParsedTicketItem(
              nombre: desc,
              precio: mNeto,
            ),
          );
        }
      }

      return TicketParseResult(
        readerName: readerName,
        items: items,
        totalDetectado: totalDet,
        rawTexts: filasTexto,
        imagePaths: imagePaths,
        diagnosticLog: logBuffer.toString(),
      );
    } catch (e) {
      stopwatch.stop();
      final elapsedSec = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

      String excType = e.runtimeType.toString();
      int statusCode = 0;
      String errBodySnippet = e.toString();

      if (e is DioException) {
        excType = 'DioException (${e.type.name})';
        statusCode = e.response?.statusCode ?? 0;
        if (e.response?.data != null) {
          final dataStr = e.response!.data.toString();
          errBodySnippet = dataStr.length > 500 ? dataStr.substring(0, 500) : dataStr;
        }
      }

      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] ERROR AL CONSULTAR OLLAMA API:');
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON]   - Excepción: $excType');
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON]   - Código HTTP: $statusCode');
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON]   - Motivo exacto: $errBodySnippet');
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] FALLBACK local: Activando MlKitTicketReader local...');
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] Tiempo transcurrido: ${elapsedSec}s');

      // Respaldo local
      final fallbackResult = await _fallbackReader.processTicketImages(imagePaths);
      return fallbackResult;
    }
  }

  void _printInChunks(String text, void Function(String msg) logMsg) {
    const int chunkSize = 750;
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      logMsg('[TICKET-DEBUG] [OLLAMA-JSON] ${text.substring(i, end)}');
    }
  }
}
