import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/widgets/account_avatar.dart';
import 'package:gastos_mobile/core/widgets/account_icon_catalog.dart';

void main() {
  test('cada ícono del catálogo tiene su imagen incluida en la app', () {
    expect(accountIconCatalog, hasLength(50));
    for (final e in accountIconCatalog) {
      expect(File(e.asset).existsSync(), isTrue, reason: e.asset);
    }
  });

  test('una clave conocida se conserva; una desconocida o vacía usa el 01', () {
    expect(AccountIcons.normalize('51'), '51');
    for (final key in ['29', 'casa', 'icon_3', '', null]) {
      expect(AccountIcons.normalize(key), defaultAccountIconKey);
      expect(AccountIcons.assetFor(key), 'assets/account_icons/01.png');
    }
  });
}
