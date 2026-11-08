import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/money/money.dart';

class SpatialTextElement {
  final String text;
  final Rect rect;

  SpatialTextElement({
    required this.text,
    required this.rect,
  });

  double get centerY => (rect.top + rect.bottom) / 2.0;
  double get height => rect.height;
}

class SpatialRow {
  final int index;
  final int topY;
  final int bottomY;
  final List<SpatialTextElement> elements;
  final String fullText;
  final int fotoOrigen;

  SpatialRow({
    required this.index,
    required this.topY,
    required this.bottomY,
    required this.elements,
    required this.fullText,
    this.fotoOrigen = 1,
  });
}

class StructuredTicketItem {
  final int renglon;
  final String descripcion;
  final String? detalleAdicional;
  /// Importes en centavos (enteros).
  final int montoBruto;
  final int descuento;
  final int montoNeto;
  final bool esDudoso;
  final String? motivo;
  final int fotoOrigen;

  StructuredTicketItem({
    required this.renglon,
    required this.descripcion,
    this.detalleAdicional,
    required this.montoBruto,
    required this.descuento,
    required this.montoNeto,
    this.esDudoso = false,
    this.motivo,
    this.fotoOrigen = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'renglon': renglon,
      'descripcion': descripcion,
      'detalle_adicional': detalleAdicional,
      'monto_bruto': montoBruto,
      'descuento': descuento,
      'monto_neto': montoNeto,
      'es_dudoso': esDudoso,
      if (motivo != null) 'motivo': motivo,
      'foto_origen': fotoOrigen,
    };
  }
}

class StructuredTicketTotals {
  /// Centavos.
  final int subtotalBruto;
  final int totalDescuentos;
  final int totalPagado;
  final String moneda;

  StructuredTicketTotals({
    required this.subtotalBruto,
    required this.totalDescuentos,
    required this.totalPagado,
    this.moneda = 'ARS',
  });

  Map<String, dynamic> toJson() {
    return {
      'subtotal_bruto': subtotalBruto,
      'total_descuentos': totalDescuentos,
      'total_pagado': totalPagado,
      'moneda': moneda,
    };
  }
}

class SpatialParseResult {
  final String? comercio;
  final String? sucursal;
  final String? direccion;
  final String? cuit;
  final String? fecha;
  final String? hora;
  final List<StructuredTicketItem> items;
  final StructuredTicketTotals totales;
  final List<SpatialRow> filasConsolidadas;

  SpatialParseResult({
    this.comercio,
    this.sucursal,
    this.direccion,
    this.cuit,
    this.fecha,
    this.hora,
    required this.items,
    required this.totales,
    this.filasConsolidadas = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'comercio': comercio,
      'sucursal': sucursal,
      'direccion': direccion,
      'cuit': cuit,
      'fecha': fecha,
      'hora': hora,
      'items': items.map((i) => i.toJson()).toList(),
      'totales': totales.toJson(),
    };
  }

  int? get totalDetectadoCents => totales.totalPagado;
}

class ReceiptSpatialParser {
  /// Procesa RecognizedText de una sola foto
  static SpatialParseResult parseRecognizedText(RecognizedText recognizedText) {
    return parseMultipleRecognizedTexts([recognizedText]);
  }

  /// Procesa RecognizedText de múltiples fotos
  static SpatialParseResult parseMultipleRecognizedTexts(List<RecognizedText> recognizedTexts) {
    if (recognizedTexts.isEmpty) {
      return SpatialParseResult(
        items: [],
        totales: StructuredTicketTotals(
          subtotalBruto: 0,
          totalDescuentos: 0,
          totalPagado: 0,
        ),
      );
    }
    final List<List<SpatialRow>> perPhotoRows = [];
    for (int p = 0; p < recognizedTexts.length; p++) {
      final rowsPhoto = _obtenerFilasHorizontales(recognizedTexts[p], p + 1);
      perPhotoRows.add(rowsPhoto);
    }
    final List<SpatialRow> filasConsolidadas = _unirYDesolaparFilas(perPhotoRows);
    return _extraerBloquesYLineas(filasConsolidadas);
  }

  /// Procesa una sola foto reconociendo filas espaciales y devuelve cadenas de texto
  static List<String> parseRecognizedTextToLines(RecognizedText recognizedText) {
    return parseMultipleRecognizedTextsToLines([recognizedText]);
  }

  /// Paso 2: Reconstruye filas por foto, las une en una sola lista ordenada y desolapa bordes
  static List<String> parseMultipleRecognizedTextsToLines(List<RecognizedText> recognizedTexts) {
    final List<List<SpatialRow>> perPhotoRows = [];

    for (int p = 0; p < recognizedTexts.length; p++) {
      final rowsPhoto = _obtenerFilasHorizontales(recognizedTexts[p], p + 1);
      perPhotoRows.add(rowsPhoto);
    }

    final List<SpatialRow> filasConsolidadas = _unirYDesolaparFilas(perPhotoRows);

    final List<String> lineasResult = [];
    debugPrint('========================================');
    debugPrint('[TICKET-DEBUG] [FILAS] (Reconstrucción Espacial Dart)');
    debugPrint('========================================');

    for (int idx = 0; idx < filasConsolidadas.length; idx++) {
      final fila = filasConsolidadas[idx];
      final lineStr = '[${fila.index.toString().padLeft(2, '0')}] ${fila.fullText}';
      lineasResult.add(lineStr);
      debugPrint('[TICKET-DEBUG] [FILAS] $lineStr');
    }

    debugPrint('========================================');
    debugPrint('[TICKET-DEBUG] [FILAS] Total de filas reconstruidas: ${lineasResult.length}');
    debugPrint('========================================');

    return lineasResult;
  }

  static List<SpatialRow> _obtenerFilasHorizontales(RecognizedText recognizedText, int fotoNum) {
    final List<SpatialTextElement> allElements = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          allElements.add(
            SpatialTextElement(
              text: text,
              rect: line.boundingBox,
            ),
          );
        }
      }
    }

    if (allElements.isEmpty) return [];

    final heights = allElements.map((e) => e.height).toList()..sort();
    final medianHeight = heights[heights.length ~/ 2];
    final double deltaY = max(8.0, medianHeight * 0.45);

    allElements.sort((a, b) => a.centerY.compareTo(b.centerY));

    final List<List<SpatialTextElement>> groupedRows = [];
    for (final elem in allElements) {
      bool matched = false;
      for (final row in groupedRows) {
        final rowCenterY = row.fold(0.0, (sum, item) => sum + item.centerY) / row.length;
        if ((elem.centerY - rowCenterY).abs() <= deltaY) {
          row.add(elem);
          matched = true;
          break;
        }
      }
      if (!matched) {
        groupedRows.add([elem]);
      }
    }

    for (final row in groupedRows) {
      row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    groupedRows.sort((a, b) => a.first.rect.top.compareTo(b.first.rect.top));

    final List<SpatialRow> spatialRows = [];
    int rowIdx = 0;
    for (final row in groupedRows) {
      rowIdx++;
      final topY = row.first.rect.top.toInt();
      final bottomY = row.fold(0.0, (maxB, item) => max(maxB, item.rect.bottom)).toInt();
      final fullText = row.map((e) => e.text).join(' ').trim();

      spatialRows.add(
        SpatialRow(
          index: rowIdx,
          topY: topY,
          bottomY: bottomY,
          elements: row,
          fullText: fullText,
          fotoOrigen: fotoNum,
        ),
      );
    }

    return spatialRows;
  }

  /// Une fotos eliminando sólo secuencias de filas consecutivas repetidas en el borde entre fotos
  static List<SpatialRow> _unirYDesolaparFilas(List<List<SpatialRow>> perPhotoRows) {
    if (perPhotoRows.isEmpty) return [];
    if (perPhotoRows.length == 1) return perPhotoRows.first;

    final List<SpatialRow> result = List.from(perPhotoRows.first);

    for (int imgIdx = 1; imgIdx < perPhotoRows.length; imgIdx++) {
      final currentRows = perPhotoRows[imgIdx];
      if (currentRows.isEmpty) continue;

      int overlapLength = 0;
      final maxCheck = min(result.length, min(currentRows.length, 6));

      for (int k = maxCheck; k >= 2; k--) {
        final tail = result.sublist(result.length - k).map((r) => r.fullText.toLowerCase()).toList();
        final head = currentRows.take(k).map((r) => r.fullText.toLowerCase()).toList();

        if (listEquals(tail, head)) {
          overlapLength = k;
          debugPrint(
            '[TICKET-DEBUG] SOLAPAMIENTO DETECTADO entre Foto #$imgIdx y #${imgIdx + 1}: $k filas consecutivas omitidas.',
          );
          break;
        }
      }

      result.addAll(currentRows.sublist(overlapLength));
    }

    final List<SpatialRow> reindexadas = [];
    for (int idx = 0; idx < result.length; idx++) {
      final r = result[idx];
      reindexadas.add(
        SpatialRow(
          index: idx + 1,
          topY: r.topY,
          bottomY: r.bottomY,
          elements: r.elements,
          fullText: r.fullText,
          fotoOrigen: r.fotoOrigen,
        ),
      );
    }

    return reindexadas;
  }

  /// Extracción sobre filas ya armadas (para probar los importes sin ML Kit).
  @visibleForTesting
  static SpatialParseResult parseRows(List<SpatialRow> rows) => _extraerBloquesYLineas(rows);

  /// Extrae ENCABEZADO, ITEMS y TOTALES sobre la lista unificada
  static SpatialParseResult _extraerBloquesYLineas(List<SpatialRow> spatialRows) {
    if (spatialRows.isEmpty) {
      return SpatialParseResult(
        items: [],
        totales: StructuredTicketTotals(
          subtotalBruto: 0,
          totalDescuentos: 0,
          totalPagado: 0,
        ),
      );
    }

    String? comercio;
    String? sucursal;
    String? direccion;
    String? cuit;
    String? fecha;
    String? hora;

    for (final fila in spatialRows) {
      final text = fila.fullText;
      final lower = text.toLowerCase();

      if (comercio == null && (lower.contains('coto') || lower.contains('goto') || lower.contains('c.i.c.s.a'))) {
        comercio = 'COTO';
      }
      if (sucursal == null && lower.contains('suc')) {
        sucursal = text.trim();
      }
      if (direccion == null && (lower.contains('avda') || lower.contains('calle') || lower.contains('paz') || lower.contains('yrigoyen'))) {
        direccion = text.trim();
      }
      if (cuit == null) {
        final matchCuit = RegExp(r'\b\d{2}-\d{8}-\d{1}\b').firstMatch(text);
        if (matchCuit != null) cuit = matchCuit.group(0);
      }
      if (fecha == null) {
        final matchFecha = RegExp(r'\b\d{2}/\d{2}/\d{4}\b').firstMatch(text);
        if (matchFecha != null) fecha = matchFecha.group(0);
      }
      if (hora == null) {
        final matchHora = RegExp(r'\b\d{2}:\d{2}(?::\d{2})?\b').firstMatch(text);
        if (matchHora != null) hora = matchHora.group(0);
      }
    }

    final List<StructuredTicketItem> items = [];
    int? totalDetectadoEnTicket;
    bool isPostTotal = false;

    for (int i = 0; i < spatialRows.length; i++) {
      final fila = spatialRows[i];
      final lower = fila.fullText.toLowerCase();

      if (lower.contains('total') && !lower.contains('subtotal') && !lower.contains('puntos')) {
        final totalMonto = _extraerMontoDeTexto(fila.fullText);
        if (totalMonto != null && totalMonto > 0) {
          totalDetectadoEnTicket = totalMonto;
        }
        isPostTotal = true;
        continue;
      }

      if (isPostTotal) continue;

      if (_esFilaIgnorable(lower) || _esSoloCodigoDeBarra(fila.fullText)) continue;

      // Fila de Código PLU + EAN con Precio al final
      if (_esFilaDeCodigoConPrecio(fila)) {
        final precioBruto = _extraerPrecioDeFila(fila);
        if (precioBruto != null && precioBruto > 0 && precioBruto <= _maxCents) {
          String descripcion = '';
          String? detalleAdicional;
          int fotoOrigenItem = fila.fotoOrigen;

          for (int j = i - 1; j >= 0; j--) {
            final prevFila = spatialRows[j];
            final prevText = prevFila.fullText;

            if (_esPatronDetalleAdicional(prevText)) {
              detalleAdicional = prevText.trim();
            } else {
              final nombreCand = _extraerDescripcionPura(prevText);
              if (nombreCand.isNotEmpty && !_esFilaIgnorable(prevText.toLowerCase())) {
                descripcion = nombreCand;
                fotoOrigenItem = prevFila.fotoOrigen;
                break;
              }
            }
          }

          if (descripcion.isNotEmpty) {
            var descuento = 0;

            if (i + 1 < spatialRows.length && _esFilaDescuento(spatialRows[i + 1])) {
              final sigFila = spatialRows[i + 1];
              if (detalleAdicional == null && _esPatronDetalleAdicional(sigFila.fullText)) {
                detalleAdicional = _extraerDetallePuro(sigFila.fullText);
              }
              final montoDesc = _extraerMontoDeTexto(sigFila.fullText);
              // Un descuento mayor o igual al precio es una lectura equivocada: no se aplica.
              if (montoDesc != null && montoDesc > 0 && montoDesc < precioBruto) {
                descuento = montoDesc;
                i++; // Consumir fila de descuento
              }
            }

            final montoNeto = max(1, precioBruto - descuento);

            items.add(
              StructuredTicketItem(
                renglon: items.length + 1,
                descripcion: descripcion,
                detalleAdicional: detalleAdicional,
                montoBruto: precioBruto,
                descuento: descuento,
                montoNeto: montoNeto,
                fotoOrigen: fotoOrigenItem,
              ),
            );
          }
        }
        continue;
      }

      // Formato C: Fila única de Nombre con Precio directo
      if (!_esPatronCantidad(fila.fullText) && !_esFilaDescuento(fila)) {
        if (i + 1 < spatialRows.length && _esFilaDeCodigoConPrecio(spatialRows[i + 1])) {
          continue;
        }

        final precio = _extraerPrecioDeFila(fila);
        final descripcion = _extraerDescripcionPura(fila.fullText);

        if (precio != null && precio > 0 && precio <= _maxCents && descripcion.isNotEmpty) {
          items.add(
            StructuredTicketItem(
              renglon: items.length + 1,
              descripcion: descripcion,
              detalleAdicional: null,
              montoBruto: precio,
              descuento: 0,
              montoNeto: precio,
              fotoOrigen: fila.fotoOrigen,
            ),
          );
        }
      }
    }

    final subtotalBruto = items.fold<int>(0, (acc, item) => acc + item.montoBruto);
    final totalDescuentos = items.fold<int>(0, (acc, item) => acc + item.descuento);
    final totalPagado = totalDetectadoEnTicket ?? subtotalBruto - totalDescuentos;

    final parseResult = SpatialParseResult(
      comercio: comercio,
      sucursal: sucursal,
      direccion: direccion,
      cuit: cuit,
      fecha: fecha,
      hora: hora,
      items: items,
      totales: StructuredTicketTotals(
        subtotalBruto: subtotalBruto,
        totalDescuentos: totalDescuentos,
        totalPagado: totalPagado,
        moneda: 'ARS',
      ),
      filasConsolidadas: spatialRows,
    );

    return parseResult;
  }

  static bool _esFilaIgnorable(String lower) {
    return lower.contains('cuit') ||
        lower.contains('subtot') ||
        lower.contains('cae') ||
        lower.contains('factura') ||
        lower.contains('ticket') ||
        lower.contains('efectivo') ||
        lower.contains('tarjeta') ||
        lower.contains('debito') ||
        lower.contains('credito') ||
        lower.contains('gracias por su compra') ||
        lower.contains('caja #') ||
        lower.contains('operador') ||
        lower.contains('puntos') ||
        lower.contains('vuelto') ||
        lower.contains('cambio');
  }

  static bool _esSoloCodigoDeBarra(String texto) {
    final clean = texto.replaceAll(' ', '').trim();
    return RegExp(r'^\d{10,28}$').hasMatch(clean);
  }

  static bool _esFilaDeCodigoConPrecio(SpatialRow fila) {
    if (_esPatronCantidad(fila.fullText)) return false;
    final hasBarcode = RegExp(r'\b\d{8,14}\b').hasMatch(fila.fullText);
    if (!hasBarcode) return false;
    final price = _extraerPrecioDecimalFinal(fila.fullText);
    return price != null && price > 0;
  }

  static bool _esFilaDescuento(SpatialRow fila) {
    final lower = fila.fullText.toLowerCase();
    // "SUBTOT. SIN DESCUENTOS" y "DESCUENTOS POR PROMOCIONES" son totales del ticket, no de un renglón.
    if (lower.contains('subtot')) return false;
    return _esLineaDescuento(lower) || lower.contains('-') || lower.contains('aj');
  }

  static bool _esPatronCantidad(String texto) {
    return RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:\(\d+\))?\s+[xX]\s+').hasMatch(texto);
  }

  static bool _esPatronDetalleAdicional(String texto) {
    return _esPatronCantidad(texto) || _esLineaDescuento(texto.toLowerCase()) || texto.contains('%');
  }

  static bool _esLineaDescuento(String lower) {
    return lower.contains('descuento') ||
        lower.contains('promo') ||
        lower.contains('bonif') ||
        lower.contains('dto') ||
        lower.contains('marcas');
  }

  static int? _extraerPrecioDeFila(SpatialRow fila) {
    if (fila.elements.isEmpty) return null;
    final rightmostText = fila.elements.last.text;
    final priceRight = _extraerMontoDeTexto(rightmostText);
    if (priceRight != null && priceRight > 0) {
      return priceRight;
    }
    return _extraerMontoDeTexto(fila.fullText);
  }

  static int? _extraerPrecioDecimalFinal(String texto) {
    final cleanSpaces = _normalizarDecimalesOcr(texto);
    final regExp = RegExp(r'\$?\s*(\b\d{1,3}(?:[.,]\d{3})*,\d{2}\b|\b\d+,\d{2}\b|\b\d+\.\d{2}\b)\s*$');
    final match = regExp.firstMatch(cleanSpaces);
    if (match != null && match.group(1) != null) {
      final parsed = _parseMontoArgentino(match.group(1)!);
      if (parsed != null && parsed > 0 && parsed <= _maxCents) {
        return parsed;
      }
    }
    return null;
  }

  static String _extraerDescripcionPura(String texto) {
    var cleaned = texto.trim();
    while (cleaned.startsWith('=') || cleaned.startsWith('-')) {
      cleaned = cleaned.substring(1).trim();
    }
    cleaned = cleaned.replaceAll(RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:\(\d+\))?\s+[xX]\s+\$?\s*\d+(?:[.,]\d+)?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$?\s*\b\d{1,3}(?:[.,]\d{3})*(?:,\d{2})\b|\$?\s*\b\d+,\d{2}\b|\$?\s*\b\d+\.\d{2}\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{2}/\d{2}/\d{2,4}\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{2}:\d{2}(?::\d{2})?\b'), '');
    return cleaned.trim();
  }

  static String _extraerDetallePuro(String texto) {
    var cleaned = texto.replaceAll(RegExp(r'\[AJ\s*-\d+(?:[.,]\d+)?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'-\d+(?:[.,]\d+)?'), '');
    return cleaned.trim();
  }

  static int? _extraerMontoDeTexto(String texto) {
    final cleanSpaces = _normalizarDecimalesOcr(texto);
    final regExpDecimal = RegExp(r'\$?\s*(\b\d{1,3}(?:[.,]\d{3})*,\d{2}\b|\b\d+,\d{2}\b|\b\d+\.\d{2}\b)');
    final matchesDecimal = regExpDecimal.allMatches(cleanSpaces);

    if (matchesDecimal.isNotEmpty) {
      final lastMatch = matchesDecimal.last.group(1);
      if (lastMatch != null) {
        return _parseMontoArgentino(lastMatch);
      }
    }
    return null;
  }

  /// Junta la coma decimal con sus dígitos, colapsa comas repetidas ("4230,, 00") y corrige la
  /// letra O leída en lugar de un cero solo en los dos decimales ("4644, O0" → "4644,00").
  static String _normalizarDecimalesOcr(String texto) => texto
      .replaceAll(RegExp(',{2,}'), ',')
      .replaceAll(' ,', ',')
      .replaceAll(', ', ',')
      .replaceAllMapped(RegExp(r'(\d,)([0-9Oo]{2})\b'), (m) => '${m[1]}${m[2]!.replaceAll(RegExp('[Oo]'), '0')}');

  /// Tope de un importe razonable en un ticket: $ 10.000.000,00.
  static const _maxCents = 1000000000;

  /// "1.234,56", "1234,56" o "1234.56" → centavos (entero, sin pasar por double).
  static int? _parseMontoArgentino(String str) {
    final clean = str.replaceAll('\$', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;

    final lastComma = clean.lastIndexOf(',');
    final lastDot = clean.lastIndexOf('.');
    final sep = lastComma != -1 && lastComma == clean.length - 3
        ? lastComma
        : (lastDot != -1 && lastDot == clean.length - 3 ? lastDot : -1);
    if (sep != -1) {
      final before = clean.substring(0, sep).replaceAll('.', '').replaceAll(',', '');
      final decimals = clean.substring(sep + 1);
      if (!RegExp(r'^\d*$').hasMatch(before) || !RegExp(r'^\d{2}$').hasMatch(decimals)) return null;
      return (before.isEmpty ? 0 : int.parse(before)) * 100 + int.parse(decimals);
    }
    return Money.parseInput(clean);
  }
}
