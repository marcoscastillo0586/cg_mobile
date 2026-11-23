import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../tickets_repository.dart';
import 'mlkit_ticket_reader.dart';

/// Lo que la pantalla "Escanear ticket" usa del celular: escáner, galería, red y lectura local. En los tests se
/// reemplaza por uno simulado.
final ticketCaptureDevicesProvider = Provider<TicketCaptureDevices>((ref) => TicketCaptureDevices());

class TicketCaptureDevices {
  final _picker = ImagePicker();

  /// Escáner de Google con recorte automático (hasta [TicketsRepository.maxImages] capturas). Lanza si el
  /// celular no lo tiene.
  Future<List<String>> scanDocument() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, pageLimit: TicketsRepository.maxImages),
    );
    return (await scanner.scanDocument()).images;
  }

  Future<List<String>> pickImages() async =>
      (await _picker.pickMultiImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 80)).map((img) => img.path).toList();

  /// Sin ninguna red (wifi, datos, ethernet). Si no se puede saber, se intenta igual.
  Future<bool> offline() async {
    try {
      return (await Connectivity().checkConnectivity()).every((r) => r == ConnectivityResult.none);
    } catch (e) {
      debugPrint('[TICKET] No se pudo consultar la red: $e');
      return false;
    }
  }

  /// Lectura en el celular (ML Kit + parser espacial): no envía datos a ningún servidor.
  Future<TicketParseResult> readLocal(List<String> paths) => MlKitTicketReader().processTicketImages(paths);
}
