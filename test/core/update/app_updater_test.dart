// Actualización sin Play Store: qué versión publicada se ofrece y de dónde se lee (la descarga y el instalador
// sólo corren en un release de Android).
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/update/app_updater.dart';

void main() {
  final published = {'version_code': 2006, 'version_name': '1.0.4', 'apk_url': 'https://x/cg.apk', 'changelog': 'Arreglos'};

  test('se ofrece sólo si la publicada es más nueva; acepta JSON o texto', () {
    final info = AppUpdater.newerThan(published, 2005);
    expect((info?.versionCode, info?.versionName, info?.apkUrl, info?.changelog), (2006, '1.0.4', 'https://x/cg.apk', 'Arreglos'));
    expect(AppUpdater.newerThan(jsonEncode(published), 2005)?.versionCode, 2006);
    expect(AppUpdater.newerThan(published, 2006), isNull);
    expect(AppUpdater.newerThan(published, 2007), isNull);
  });

  test('version.json sin lo mínimo no ofrece nada; nombre por defecto = código', () {
    expect(AppUpdater.newerThan({'version_code': 3000}, 1), isNull);
    expect(AppUpdater.newerThan({'version_code': '3000', 'apk_url': 'u'}, 1), isNull);
    expect(AppUpdater.newerThan({'version_code': 3000, 'apk_url': ''}, 1), isNull);
    expect(AppUpdater.newerThan([1, 2], 1), isNull);
    final info = AppUpdater.newerThan({'version_code': 3000, 'apk_url': 'u'}, 1)!;
    expect((info.versionName, info.changelog), ('3000', ''));
  });

  test('dirección de version.json: la fijada al compilar o el host de la API', () {
    expect(AppUpdater.versionUrlFor('https://otro/v.json', 'https://api.x/api/v1'), 'https://otro/v.json');
    expect(AppUpdater.versionUrlFor('', 'https://gastos.ejemplo.com/api/v1'), 'https://gastos.ejemplo.com/downloads/version.json');
    expect(AppUpdater.versionUrlFor('', null), isNull);
    expect(AppUpdater.versionUrlFor('', 'no es url'), isNull);
  });
}
