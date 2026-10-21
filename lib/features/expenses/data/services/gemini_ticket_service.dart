import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/ticket_data.dart';

class GeminiTicketService {
  final Dio _dio;
  final String apiKey;

  static const String _geminiPrompt = r'''
Eres un motor de visión e inteligencia artificial especializado en extracción estructurada de comprobantes y tickets de compra argentinos.
Tu tarea es analizar detalladamente las imágenes del ticket adjuntas y extraer los datos en formato JSON estricto.

REGLAS DE EXTRACCIÓN:
1. "comercio": Nombre comercial o razón social del establecimiento (ej. "COTO", "CARREFOUR", "JUMBO").
2. "cuit": CUIT del emisor si está visible (ej. "30-54808315-6").
3. "fecha": Fecha en formato dd/mm/aaaa si está visible.
4. "hora": Hora en formato hh:mm:ss si está visible.
5. "items": Lista de productos comprados.
   - "descripcion": Nombre limpio del producto sin precios ni códigos.
   - "cantidad": Cantidad de unidades o pesaje (numérico float, ej. 1.0, 0.970, 5.0). Si no figura, usa 1.0.
   - "precio_unitario": Precio por unidad o por kilo si figura explícito.
   - "precio_bruto": Monto de la línea antes de aplicar el descuento.
   - "descuento": Monto positivo del descuento o bonificación aplicada a este ítem (0.0 si no hay).
   - "precio_final": Monto neto de la línea (precio_bruto - descuento).
6. DESCUENTO: Las líneas con leyendas como "DESC", "DTO", "BONIFICACIÓN", "-1038,10", "35% MARCAS" o importes negativos se deben restar del producto inmediatamente anterior en su campo "descuento".
7. IGNORAR: Códigos de barras de PLU/EAN aislados, datos de medios de pago, vuelto, leyendas fiscales y texto posterior a la línea TOTAL.

Responde únicamente con un objeto JSON válido con esta estructura exacta:
{
  "comercio": string|null,
  "cuit": string|null,
  "fecha": "dd/mm/aaaa"|null,
  "hora": "hh:mm:ss"|null,
  "items": [
    {
      "descripcion": string,
      "cantidad": number,
      "precio_unitario": number|null,
      "precio_bruto": number,
      "descuento": number,
      "precio_final": number
    }
  ],
  "descuento_general": number,
  "total": number|null
}
''';

  GeminiTicketService({
    Dio? dio,
    required this.apiKey,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  /// Redimensiona y comprime la foto a un máximo de 1024px (<300 KB) antes de enviar a Gemini
  Future<String> _readResizedBase64Image(File file, {int maxDimension = 1024}) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes <= 300 * 1024) {
        return base64Encode(bytes);
      }

      final codec = await instantiateImageCodec(
        bytes,
        targetWidth: maxDimension,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();

      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('[GEMINI-AI] Fallback en compresión de imagen ($e). Usando bytes originales.');
    }
    return base64Encode(await file.readAsBytes());
  }

  Future<TicketData> extractTicketWithGemini(List<File> imageFiles) async {
    try {
      final List<Map<String, dynamic>> parts = [
        {'text': _geminiPrompt}
      ];

      for (final file in imageFiles) {
        if (await file.exists()) {
          final base64Image = await _readResizedBase64Image(file);
          parts.add({
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Image,
            }
          });
        }
      }

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$apiKey';

      final payload = {
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.1,
        }
      };

      debugPrint('[GEMINI-AI] Enviando ${imageFiles.length} foto(s) optimizada(s) a Google Gemini 3.8 Flash API...');
      final Stopwatch sw = Stopwatch()..start();

      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
      );

      sw.stop();
      final elapsedSec = (sw.elapsedMilliseconds / 1000).toStringAsFixed(2);
      debugPrint('[GEMINI-AI] Respuesta recibida de Gemini AI en $elapsedSec segundos!');

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data!['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw const FormatException('Gemini AI no devolvió candidatos en la respuesta');
        }

        final content = candidates.first['content'];
        final partsList = content['parts'] as List<dynamic>?;
        if (partsList == null || partsList.isEmpty) {
          throw const FormatException('Gemini AI no devolvió texto en las partes del contenido');
        }

        final rawJsonStr = partsList.first['text']?.toString().trim();
        if (rawJsonStr == null || rawJsonStr.isEmpty) {
          throw const FormatException('El texto JSON devuelto por Gemini AI está vacío');
        }

        debugPrint('[GEMINI-AI] JSON ESTRUCTURADO DEVUELTO POR GEMINI AI:\n$rawJsonStr');

        final Map<String, dynamic> jsonMap = jsonDecode(rawJsonStr) as Map<String, dynamic>;
        return TicketData.fromJson(jsonMap);
      } else {
        throw Exception('Respuesta inesperada de Gemini AI. Código HTTP: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw TimeoutException('La consulta a Google Gemini AI excedió el tiempo de espera (90s).');
      }
      throw Exception('Error de red al consultar Google Gemini AI: ${e.message}');
    } on FormatException catch (e) {
      throw FormatException('Error al parsear el JSON de Gemini AI: $e');
    } catch (e) {
      throw Exception('Error inesperado en GeminiTicketService: $e');
    }
  }
}
