import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/update/app_updater.dart';

void main() {
  test('lee version.json completo', () {
    final info = UpdateInfo.fromJson({
      'version_code': 3,
      'version_name': '1.0.0',
      'apk_url': 'http://192.168.0.50/downloads/cg-3.apk',
      'changelog': 'Escanear ticket avisa sin conexión',
    })!;
    expect(info.versionCode, 3);
    expect(info.versionName, '1.0.0');
    expect(info.apkUrl, 'http://192.168.0.50/downloads/cg-3.apk');
    expect(info.changelog, 'Escanear ticket avisa sin conexión');
  });

  test('sin version_code o apk_url no hay actualización', () {
    expect(UpdateInfo.fromJson({'apk_url': 'http://x/a.apk'}), isNull);
    expect(UpdateInfo.fromJson({'version_code': 3}), isNull);
    expect(UpdateInfo.fromJson({'version_code': '3', 'apk_url': 'http://x/a.apk'}), isNull);
    expect(UpdateInfo.fromJson('no es un objeto'), isNull);
  });

  test('sin nombre ni novedades usa valores por defecto', () {
    final info = UpdateInfo.fromJson({'version_code': 4, 'apk_url': 'http://x/a.apk'})!;
    expect(info.versionName, '4');
    expect(info.changelog, '');
  });
}
