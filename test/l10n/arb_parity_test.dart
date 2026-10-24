// Traducciones: español (plantilla) e inglés con las mismas claves y los mismos parámetros.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _messages(String file) {
  final json = jsonDecode(File('lib/l10n/$file').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

Set<String> _params(String text) => {for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) m.group(1)!};

void main() {
  final es = _messages('app_es.arb');
  final en = _messages('app_en.arb');

  test('mismas claves en español e inglés', () {
    expect(en.keys.toSet().difference(es.keys.toSet()), isEmpty, reason: 'claves solo en inglés');
    expect(es.keys.toSet().difference(en.keys.toSet()), isEmpty, reason: 'claves sin traducir al inglés');
  });

  test('mismos parámetros y ningún texto vacío', () {
    for (final k in es.keys) {
      expect(es[k]!.trim(), isNotEmpty, reason: '$k vacío en español');
      expect(en[k]!.trim(), isNotEmpty, reason: '$k vacío en inglés');
      expect(_params(en[k]!), _params(es[k]!), reason: 'parámetros de $k');
    }
  });

  test('no quedan textos elegidos con isEn en el código', () {
    final restos = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && RegExp(r'\bisEn\b').hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(restos, isEmpty);
  });
}
