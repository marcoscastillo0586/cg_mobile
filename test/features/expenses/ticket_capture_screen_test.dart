// "Escanear ticket" con escáner, galería, red, lectura local y servidor SIMULADOS (ML Kit y la cámara se prueban
// en el celular).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/expenses/data/services/ticket_capture_devices.dart';
import 'package:gastos_mobile/features/expenses/data/tickets_repository.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/ticket_parse_result.dart';
import 'package:gastos_mobile/features/expenses/presentation/screens/ticket_capture_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import '../../helpers/screen.dart';

// PNG de 1x1 para que Image.file tenga algo que dibujar.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

TicketParseResult _lectura(int renglones) => TicketParseResult(
      readerName: 'x',
      items: [for (var i = 0; i < renglones; i++) ParsedTicketItem(nombre: 'P$i', precioCents: 100)],
      rawTexts: const [],
      imagePaths: const [],
    );

class _Devices implements TicketCaptureDevices {
  bool sinRed = false;
  Object? errorEscaner;
  Object? errorGaleria;
  List<String> escaneadas = [];
  List<String> galeria = [];
  Future<TicketParseResult> Function(List<String>) local = (_) async => _lectura(2);

  @override
  Future<bool> offline() async => sinRed;
  @override
  Future<List<String>> scanDocument() async => errorEscaner == null ? escaneadas : throw errorEscaner!;
  @override
  Future<List<String>> pickImages() async => errorGaleria == null ? galeria : throw errorGaleria!;
  @override
  Future<TicketParseResult> readLocal(List<String> paths) => local(paths);
}

class _Tickets implements TicketsRepository {
  Completer<TicketParseResult> respuesta = Completer();
  CancelToken? token;
  @override
  Future<TicketParseResult> readImages(List<String> imagePaths, {CancelToken? cancelToken}) {
    token = cancelToken;
    return respuesta.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l = lookupAppLocalizations(const Locale('es'));
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('ticket_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  List<String> capturas(int n) => [
        for (var i = 0; i < n; i++) (File('${dir.path}/c$i.png')..writeAsBytesSync(_png)).path,
      ];

  Future<(_Devices, _Tickets)> abrir(WidgetTester tester) async {
    final devices = _Devices();
    final tickets = _Tickets();
    await pumpScreen(tester, const TicketCaptureScreen(), pushed: true, overrides: [
      ticketCaptureDevicesProvider.overrideWithValue(devices),
      ticketsRepositoryProvider.overrideWithValue(tickets),
    ]);
    return (devices, tickets);
  }

  testWidgets('sin red, Escanear avisa que requiere conexión', (tester) async {
    final (devices, _) = await abrir(tester);
    devices.sinRed = true;
    await tester.tap(find.text(l.scan2));
    await tester.pumpAndSettle();
    expect(find.text(l.scanRequiresConnection), findsOneWidget);
  });

  testWidgets('Escanear: lee en el servidor y vuelve al egreso con los renglones', (tester) async {
    final (devices, tickets) = await abrir(tester);
    devices.escaneadas = capturas(2);
    await tester.tap(find.text(l.scan2));
    await tester.pump();
    await tester.pump();
    expect(find.text(l.readingReceiptServer), findsOneWidget);
    tickets.respuesta.complete(_lectura(3));
    await tester.pumpAndSettle();
    expect(find.text('inicio'), findsOneWidget);
    expect(find.text(l.receiptReadLines(3)), findsOneWidget);
    expect(File(devices.escaneadas.first).existsSync(), isTrue); // se usan en el egreso
  });

  testWidgets('Escanear sin renglones o con el servidor caído: avisa, se queda y borra las capturas', (tester) async {
    final (devices, tickets) = await abrir(tester);
    devices.escaneadas = capturas(1);
    await tester.tap(find.text(l.scan2));
    await tester.pump();
    tickets.respuesta.complete(_lectura(0));
    await tester.pumpAndSettle();
    expect(find.text(l.noProductsWereDetectedReceipt), findsOneWidget);
    expect(File(devices.escaneadas.single).existsSync(), isFalse);

    for (final (error, aviso) in [
      (const ServerException('foto inválida', 400, 'VALIDATION_ERROR'), l.couldNotReadReceipt('foto inválida')),
      (const ServerException('x', 503, 'TEMPORARY_ERROR'), l.scanRequiresConnection),
    ]) {
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
      devices.escaneadas = capturas(1);
      tickets.respuesta = Completer();
      await tester.tap(find.text(l.scan2));
      await tester.pump();
      tickets.respuesta.completeError(error);
      await tester.pumpAndSettle();
      expect(find.text(aviso), findsOneWidget);
      expect(find.text('inicio'), findsNothing);
    }
  });

  testWidgets('cancelar la lectura en el servidor vuelve a la pantalla sin avisos', (tester) async {
    final (devices, tickets) = await abrir(tester);
    devices.escaneadas = capturas(1);
    await tester.tap(find.text(l.scan2));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cancelar-lectura-servidor')));
    await tester.pump();
    expect(tickets.token!.isCancelled, isTrue);
    tickets.respuesta.complete(_lectura(2));
    await tester.pumpAndSettle();
    expect(find.text(l.scan2), findsOneWidget);
    expect(find.text('inicio'), findsNothing);
  });

  testWidgets('escáner cancelado no hace nada; sin escáner ofrece la galería', (tester) async {
    final (devices, _) = await abrir(tester);
    await tester.tap(find.text(l.scan2));
    await tester.pumpAndSettle();
    expect(find.text(l.readingReceiptServer), findsNothing);
    devices.errorEscaner = Exception('sin escáner');
    devices.galeria = [];
    await tester.tap(find.text(l.scan2));
    await tester.pumpAndSettle();
    expect(find.text(l.scannerNotAvailableDeviceSelect), findsOneWidget);
  });

  testWidgets('galería: lee en el celular y vuelve con los renglones', (tester) async {
    final (devices, _) = await abrir(tester);
    devices.galeria = capturas(2);
    final lectura = Completer<TicketParseResult>();
    devices.local = (_) => lectura.future;
    await tester.tap(find.text(l.gallery));
    await tester.pump();
    await tester.pump();
    expect(find.text(l.readingReceiptDevice), findsOneWidget);
    lectura.complete(_lectura(2));
    await tester.pumpAndSettle();
    expect(find.text(l.receiptReadDeviceLines(2)), findsOneWidget);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('galería sin renglones: quedan las fotos; quitar una, IA no disponible y reintentar con error', (tester) async {
    final (devices, _) = await abrir(tester);
    devices.galeria = capturas(2);
    devices.local = (_) async => _lectura(0);
    await tester.tap(find.text(l.gallery));
    await tester.pumpAndSettle();
    expect(find.text(l.noProductsWereDetectedReceipt), findsOneWidget);
    expect(find.text(l.scan(2)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quitar-captura-1')));
    await tester.pump();
    expect(find.text(l.scan(2)), findsNothing);
    expect(File(devices.galeria.last).existsSync(), isFalse);

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.readAi));
    await tester.pump();
    expect(find.text(l.featureNotAvailableNow), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
    devices.local = (_) async => throw Exception('ML Kit');
    await tester.tap(find.text(l.finishLoading));
    await tester.pumpAndSettle();
    expect(find.textContaining('ML Kit'), findsOneWidget);
  });

  testWidgets('galería sin elegir nada no hace nada; sin acceso avisa', (tester) async {
    final (devices, _) = await abrir(tester);
    await tester.tap(find.text(l.gallery));
    await tester.pumpAndSettle();
    expect(find.text(l.noScansAddedYet), findsOneWidget);
    devices.errorGaleria = Exception('permiso');
    await tester.tap(find.text(l.gallery));
    await tester.pumpAndSettle();
    expect(find.text(l.couldNotAccessGalleryCheck), findsOneWidget);
  });

  testWidgets('cada falla de la lectura muestra su mensaje (y solo la falta de conexión dice "requiere conexión")', (tester) async {
    final (devices, tickets) = await abrir(tester);
    final casos = [
      ('GEMINI_OVERLOADED', 503, l.errGeminiOverloaded),
      ('GEMINI_QUOTA', 429, l.errGeminiQuota),
      ('GEMINI_TIMEOUT', 504, l.errGeminiTimeout),
      ('GEMINI_INVALID', 502, l.errGeminiInvalid),
      ('GEMINI_UNAVAILABLE', 503, l.errGeminiUnavailable),
      ('GEMINI_NOT_CONFIGURED', 503, l.errGeminiUnavailable),
    ];
    for (final (code, status, mensaje) in casos) {
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
      devices.escaneadas = capturas(1);
      tickets.respuesta = Completer();
      await tester.tap(find.text(l.scan2));
      await tester.pump();
      tickets.respuesta.completeError(ServerException('detalle del servidor', status, code));
      await tester.pumpAndSettle();
      expect(find.text(mensaje), findsOneWidget, reason: code);
      expect(find.text(l.scanRequiresConnection), findsNothing, reason: code);
    }
    // Sin conexión de verdad (error de red): sí.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
    devices.escaneadas = capturas(1);
    tickets.respuesta = Completer();
    await tester.tap(find.text(l.scan2));
    await tester.pump();
    tickets.respuesta.completeError(const NetworkException());
    await tester.pumpAndSettle();
    expect(find.text(l.scanRequiresConnection), findsOneWidget);
  });
}
