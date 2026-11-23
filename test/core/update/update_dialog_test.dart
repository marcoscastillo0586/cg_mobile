// Ventana "Hay una actualización" con descarga e instalación SIMULADAS (el instalador real se prueba en el celular).
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/update/app_updater.dart';
import 'package:gastos_mobile/core/update/update_dialog.dart';
import 'package:gastos_mobile/l10n/app_localizations.dart';

const _info = UpdateInfo(versionCode: 2006, versionName: '2.0.6', apkUrl: 'http://x/cg.apk', changelog: ' Arreglos varios ');

void main() {
  final l = lookupAppLocalizations(const Locale('es'));

  Future<void> abrir(WidgetTester tester, {required ApkDownload download, required Future<bool> Function(String) install}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(context: context, builder: (_) => UpdateDialog(info: _info, download: download, install: install)),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('versión y novedades; "Más tarde" cierra sin descargar', (tester) async {
    var descargas = 0;
    await abrir(tester, download: (_, {onProgress, cancelToken}) async => '${descargas++}', install: (_) async => true);
    expect(find.text(l.updateAvailableVersion('2.0.6')), findsOneWidget);
    expect(find.text('Arreglos varios'), findsOneWidget);
    await tester.tap(find.text(l.updateLater));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(descargas, 0);
  });

  testWidgets('descarga con progreso y abre el instalador: la ventana se cierra', (tester) async {
    final fin = Completer<String>();
    void Function(double?)? progreso;
    final instalados = <String>[];
    await abrir(tester, download: (_, {onProgress, cancelToken}) {
      progreso = onProgress;
      return fin.future;
    }, install: (apk) async {
      instalados.add(apk);
      return true;
    });
    await tester.tap(find.text(l.updateNow));
    await tester.pump();
    expect(find.text(l.updateDownloading), findsOneWidget);
    progreso!(0.42);
    await tester.pump();
    expect(find.text('42%'), findsOneWidget);
    fin.complete('/tmp/cg.apk');
    await tester.pumpAndSettle();
    expect(instalados, ['/tmp/cg.apk']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('sin permiso para instalar avisa; al reintentar no vuelve a descargar', (tester) async {
    var descargas = 0;
    var permiso = false;
    await abrir(tester, download: (_, {onProgress, cancelToken}) async => 'apk${descargas++}', install: (_) async => permiso);
    await tester.tap(find.text(l.updateNow));
    await tester.pumpAndSettle();
    expect(find.text(l.updateNeedsPermission), findsOneWidget);
    permiso = true;
    await tester.tap(find.text(l.updateNow));
    await tester.pumpAndSettle();
    expect(descargas, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('descarga fallida o instalador que no abre: se avisa', (tester) async {
    var fallaDescarga = true;
    await abrir(tester, download: (_, {onProgress, cancelToken}) async {
      if (fallaDescarga) throw Exception('sin red');
      return 'apk';
    }, install: (_) async => throw Exception('sin instalador'));
    await tester.tap(find.text(l.updateNow));
    await tester.pumpAndSettle();
    expect(find.text(l.updateDownloadFailed), findsOneWidget);
    fallaDescarga = false;
    await tester.tap(find.text(l.updateNow));
    await tester.pumpAndSettle();
    expect(find.text(l.updateInstallFailed), findsOneWidget);
  });

  testWidgets('cancelar durante la descarga la corta y cierra sin avisar', (tester) async {
    CancelToken? token;
    final fin = Completer<String>();
    await abrir(tester, download: (_, {onProgress, cancelToken}) {
      token = cancelToken;
      return fin.future;
    }, install: (_) async => true);
    await tester.tap(find.text(l.updateNow));
    await tester.pump();
    final cancelar = MaterialLocalizations.of(tester.element(find.byType(AlertDialog))).cancelButtonLabel;
    await tester.tap(find.text(cancelar));
    await tester.pumpAndSettle();
    expect(token!.isCancelled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    fin.completeError(DioException.requestCancelled(requestOptions: RequestOptions(), reason: 'x'));
    await tester.pump();
  });

  test('fuera de un release de Android no se consulta nada', () async {
    expect(AppUpdater.supported, isFalse);
    expect(await AppUpdater.check(), isNull);
  });
}
