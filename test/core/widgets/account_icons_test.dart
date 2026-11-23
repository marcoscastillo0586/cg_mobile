import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/widgets/account_avatar.dart';
import 'package:gastos_mobile/core/widgets/account_icon_catalog.dart';

void main() {
  test('el catálogo y las imágenes incluidas en la app coinciden una a una', () {
    final files = Directory('assets/account_icons').listSync().map((f) => f.path.replaceAll(r'\', '/')).toSet();
    expect(accountIconCatalog.map((e) => e.asset).toSet(), files);
    expect(accountIconCatalog.map((e) => e.key).toSet(), hasLength(accountIconCatalog.length));
  });

  test('una clave conocida se conserva; una desconocida o vacía usa el 01', () {
    expect(AccountIcons.normalize('51'), '51');
    for (final key in ['29', 'casa', 'icon_3', '', null]) {
      expect(AccountIcons.normalize(key), defaultAccountIconKey);
      expect(AccountIcons.assetFor(key), 'assets/account_icons/01.png');
    }
  });
}
