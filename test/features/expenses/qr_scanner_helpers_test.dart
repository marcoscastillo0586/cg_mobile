// Reglas del escáner de QR sin cámara: qué QR es un ticket, qué código se usa, mensajes y armado del resultado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/errors/exceptions.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/qr_ticket.dart';
import 'package:gastos_mobile/features/expenses/domain/entities/ticket_parse_result.dart';
import 'package:gastos_mobile/features/expenses/presentation/screens/qr_scanner_screen.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  test('solo una dirección http/https es un ticket digital (sin espacios alrededor)', () {
    expect(qrUrl('  https://afip.gob.ar/fe/qr/?p=1 '), 'https://afip.gob.ar/fe/qr/?p=1');
    expect(qrUrl('http://x'), 'http://x');
    expect(qrUrl('WIFI:S:casa;'), isNull);
    expect(qrUrl('ftp://x'), isNull);
  });

  test('de una captura se usa el primer código con contenido', () {
    expect(primerCodigo(const [Barcode(rawValue: null), Barcode(rawValue: ''), Barcode(rawValue: 'a'), Barcode(rawValue: 'b')]), 'a');
    expect(primerCodigo(const [Barcode(rawValue: '')]), isNull);
    expect(primerCodigo(const []), isNull);
  });

  test('motivo del fallo: sin conexión pide conexión; si no, el motivo con su código', () {
    expect(motivoFalloQr(const ServerException('x', 503, 'TEMPORARY_ERROR'), l), l.qrNeedsConnection);
    final motivo = motivoFalloQr(const ServerException('ticket vencido', 422, 'VALIDATION_ERROR'), l);
    expect(motivo, endsWith(' (VALIDATION_ERROR)'));
    expect(motivoFalloQr(StateError('x'), l), isNot(contains('(')));
  });

  test('error de cámara: permiso, sin cámara y otro', () {
    expect(errorDeCamara(MobileScannerErrorCode.permissionDenied, l), l.cameraPermissionDenied);
    expect(errorDeCamara(MobileScannerErrorCode.unsupported, l), l.cameraUnsupported);
    expect(errorDeCamara(MobileScannerErrorCode.genericError, l), l.cameraError);
  });

  test('resultado de un ticket por QR: renglones netos, dudosos, total impreso y la dirección', () {
    const qr = QrTicket(
      reader: 'arca',
      sourceUrl: 'https://x',
      merchant: 'Súper',
      totalPrintedCents: 1500,
      itemsTotalCents: 1500,
      items: [
        QrTicketItem(description: 'Pan', plu: null, unitPriceCents: null, netCents: 1000, suggestedCategoryServerId: null, doubtful: false),
        QrTicketItem(description: 'Leche', plu: null, unitPriceCents: null, netCents: 500, suggestedCategoryServerId: null, doubtful: true),
      ],
    );
    final r = TicketParseResult.fromQr(qr, 'https://x');
    expect(r.readerName, 'arca');
    expect(r.items.map((i) => (i.nombre, i.precioCents, i.esDudoso)), [('Pan', 1000, false), ('Leche', 500, true)]);
    expect(r.totalDetectadoCents, 1500);
    expect(r.rawTexts, ['https://x']);
    expect(r.qr, qr);
  });
}
