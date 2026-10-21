import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/ticket_data.dart';

class OllamaTicketService {
  final Dio _dio;
  final String baseUrl;

  static const String _verbatimPrompt = r'''
Eres un motor de extracción visual de datos de comprobantes. Tu tarea es transcribir única y exclusivamente la información que sea visible y legible en la imagen adjunta.

REGLAS DE ORO CONTRA ALUCINACIONES:
1. NO CALCULES NI DEDUZCAS: Si el importe total, una fecha o un precio no aparecen físicamente impresos, coloca null. Jamás sumes o calcules subtotales por tu cuenta.
2. COMPROBANTES PARCIALES: La imagen puede mostrar un ticket cortado (sin encabezado, sin pie o solo una sección de productos). Procesa únicamente lo que esté visible dentro del encuadre.
3. EXCLUSIÓN DE BASURA VISUAL: No incluyas números de CUIT/RUT, números de terminal, códigos de barra, CAI/CAE, leyendas fiscales ("IVA discriminado", "Original") ni datos de medios de pago en la lista de items.
4. DESCUENTOS: Las líneas con descripciones como "DESC", "DTO", "BONIFICACIÓN" o importes negativos (-) deben registrarse en el campo "descuento" del ítem correspondiente o en "descuento_general", nunca como un nuevo ítem de compra.
5. TIPOS DE DATOS: Todos los importes y cantidades deben ser números (float/int). Si una cantidad no figura explícita, usa 1.0. Si un descuento no existe, usa 0.0.

Responde únicamente con un objeto JSON válido con la siguiente estructura:
{
  "comercio": string | null,
  "fecha": string | null,
  "moneda": string | null,
  "items": [
    {
      "descripcion": string,
      "cantidad": number,
      "precio_unitario": number | null,
      "descuento": number,
      "subtotal": number
    }
  ],
  "descuento_general": number,
  "total": number | null
}
''';

  OllamaTicketService({
    Dio? dio,
    this.baseUrl = 'http://10.0.2.2:11434',
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  Future<TicketData> extractTicketData(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        throw Exception('El archivo de imagen especificado no existe: ${imageFile.path}');
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = '$baseUrl/api/generate';
      final payload = {
        'model': 'qwen2.5vl:7b',
        'stream': false,
        'format': 'json',
        'images': [base64Image],
        'prompt': _verbatimPrompt,
      };

      debugPrint('[OLLAMA-SERVICE] Enviando petición de extracción visual a Ollama ($baseUrl)...');
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawResponseText = response.data!['response']?.toString().trim();
        if (rawResponseText == null || rawResponseText.isEmpty) {
          throw const FormatException('Ollama devolvió una respuesta vacía');
        }

        debugPrint('[OLLAMA-SERVICE] JSON crudo devuelto por qwen2.5vl:7b:\n$rawResponseText');

        final Map<String, dynamic> jsonMap = jsonDecode(rawResponseText) as Map<String, dynamic>;
        return TicketData.fromJson(jsonMap);
      } else {
        throw Exception('Respuesta inesperada de Ollama. Código HTTP: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw TimeoutException('La inferencia visual en Ollama excedió el tiempo de espera (90s).');
      }
      if (e.error is SocketException) {
        throw SocketException('No se pudo conectar con el servidor Ollama en $baseUrl. Verifica que Ollama esté corriendo.');
      }
      throw Exception('Error de red al consultar Ollama: ${e.message}');
    } on FormatException catch (e) {
      throw FormatException('Fallo al parsear la estructura JSON devuelta por el modelo: $e');
    } catch (e) {
      throw Exception('Error inesperado en OllamaTicketService: $e');
    }
  }
}
