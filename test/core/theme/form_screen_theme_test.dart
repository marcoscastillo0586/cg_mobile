// Tema de los formularios: borde y halo de los campos según foco/error/renglón, e interpolación claro↔oscuro.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_mobile/core/theme/form_screen_theme.dart';

void main() {
  const t = FormScreenTheme.light;

  test('campo: sin foco con sombra; con foco o error, borde de acento; con foco, halo', () {
    final quieto = t.fieldDecoration(focused: false);
    expect((quieto.border! as Border).top.color, t.border);
    expect(quieto.boxShadow, t.shadow);
    expect(quieto.color, t.surface);

    final foco = t.fieldDecoration(focused: true);
    expect((foco.border! as Border).top.color, t.accent);
    expect(foco.boxShadow!.single.spreadRadius, 4);

    expect((t.fieldDecoration(focused: false, error: true).border! as Border).top.color, t.accent);
  });

  test('campo de un renglón: fondo interno sin foco, halo más chico con foco, sin sombra', () {
    final quieto = t.fieldDecoration(focused: false, inner: true);
    expect(quieto.color, t.innerField);
    expect(quieto.boxShadow, isEmpty);
    expect(quieto.borderRadius, BorderRadius.circular(FormScreenTheme.innerRadius));
    final foco = t.fieldDecoration(focused: true, inner: true);
    expect((foco.color, foco.boxShadow!.single.spreadRadius), (t.surface, 2));
  });

  test('interpolación: sin otro tema queda igual; en los extremos, cada tema', () {
    expect(t.lerp(null, 0.5), same(t));
    expect(t.lerp(FormScreenTheme.dark, 0).background, t.background);
    expect(t.lerp(FormScreenTheme.dark, 1).accent, FormScreenTheme.dark.accent);
    expect(t.copyWith(), same(t));
  });

  testWidgets('of(): el del tema de la app o, si falta, el claro', (tester) async {
    late FormScreenTheme leido;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      leido = FormScreenTheme.of(c);
      return const SizedBox();
    })));
    expect(leido, same(FormScreenTheme.light));
  });
}
