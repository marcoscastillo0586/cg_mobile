import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Colores, radios, sombras y textos de los formularios con el diseño de "Nuevo Egreso".
/// Se registra en [ThemeData.extensions] (claro y oscuro); los widgets lo leen con [FormScreenTheme.of].
/// En oscuro se usan los colores oscuros de siempre de la app.
@immutable
class FormScreenTheme extends ThemeExtension<FormScreenTheme> {
  /// Fondo de la pantalla y de la barra superior.
  final Color background;

  /// Tarjetas y campos principales.
  final Color surface;

  /// Campos dentro de un renglón (sin foco).
  final Color innerField;
  final Color border;

  /// Borde punteado de "Agregar Renglón".
  final Color dashedBorder;

  /// Etiquetas de sección ("CUENTA DE ORIGEN", "RENGLONES").
  final Color sectionLabel;

  /// Etiquetas de campo ("CONCEPTO GENERAL", "MONTO").
  final Color fieldLabel;
  final Color text;
  final Color title;
  final Color hint;

  /// Íconos de los campos y el "$" del monto.
  final Color icon;

  /// Rosa: selección, punto, foco y asterisco.
  final Color accent;

  /// Rosa principal: botón inferior, textos de acción y total.
  final Color accentStrong;

  /// Botón inferior presionado.
  final Color accentPressed;
  final Color accentSoft;
  final Color accentSoftBorder;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color badgeText;
  final Color pillNeutral;
  final Color pillNeutralText;

  /// Papelera del renglón (se pone [accent] al presionar).
  final Color deleteIcon;
  final List<BoxShadow> shadow;
  final List<BoxShadow> floatShadow;

  const FormScreenTheme({
    required this.background,
    required this.surface,
    required this.innerField,
    required this.border,
    required this.dashedBorder,
    required this.sectionLabel,
    required this.fieldLabel,
    required this.text,
    required this.title,
    required this.hint,
    required this.icon,
    required this.accent,
    required this.accentStrong,
    required this.accentPressed,
    required this.accentSoft,
    required this.accentSoftBorder,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.badgeText,
    required this.pillNeutral,
    required this.pillNeutralText,
    required this.deleteIcon,
    required this.shadow,
    required this.floatShadow,
  });

  /// Campos principales y tarjetas.
  static const double radius = 16;

  /// Campos dentro de un renglón.
  static const double innerRadius = 12;

  /// Insignia "Renglón #N".
  static const double badgeRadius = 8;

  /// Botón inferior "Registrar Gasto".
  static const double bottomButtonHeight = 56;

  static const _floatShadow = [
    BoxShadow(color: Color(0x40E11D48), blurRadius: 25, spreadRadius: -5, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x33E11D48), blurRadius: 10, spreadRadius: -6, offset: Offset(0, 8)),
  ];

  static const light = FormScreenTheme(
    background: AppColors.lightBg,
    surface: AppColors.lightSurface,
    innerField: Color(0xFFFAFBFD), // slate-50 al 70 % sobre blanco
    border: AppColors.lightBorder,
    dashedBorder: AppColors.lightBorder,
    sectionLabel: AppColors.slate400,
    fieldLabel: AppColors.lightTextSecondary,
    text: AppColors.slate800,
    title: AppColors.lightTextPrimary,
    hint: AppColors.slate400,
    icon: AppColors.slate400,
    accent: AppColors.brand500,
    accentStrong: AppColors.brand600,
    accentPressed: AppColors.brand700,
    accentSoft: AppColors.brand50,
    accentSoftBorder: AppColors.brand100,
    badgeBackground: AppColors.indigo50,
    badgeBorder: AppColors.indigo100,
    badgeText: AppColors.indigo700,
    pillNeutral: AppColors.slate100,
    pillNeutralText: AppColors.slate600,
    deleteIcon: AppColors.slate300,
    shadow: [
      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    floatShadow: _floatShadow,
  );

  static const dark = FormScreenTheme(
    background: AppColors.darkBg,
    surface: AppColors.darkSurface,
    innerField: AppColors.darkSurface,
    border: AppColors.darkBorder,
    dashedBorder: AppColors.darkBorder,
    sectionLabel: AppColors.darkTextSecondary,
    fieldLabel: AppColors.darkTextSecondary,
    text: AppColors.darkTextPrimary,
    title: AppColors.darkTextPrimary,
    hint: AppColors.darkTextSecondary,
    icon: AppColors.darkTextSecondary,
    accent: AppColors.rose,
    accentStrong: AppColors.rose,
    accentPressed: AppColors.brand600,
    accentSoft: Color(0x40F43F5E),
    accentSoftBorder: Color(0x4DF43F5E),
    badgeBackground: Color(0x1F4F46E5),
    badgeBorder: Color(0x334F46E5),
    badgeText: AppColors.primaryLight,
    pillNeutral: AppColors.darkBorder,
    pillNeutralText: AppColors.darkTextSecondary,
    deleteIcon: AppColors.darkTextSecondary,
    shadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
    floatShadow: _floatShadow,
  );

  static FormScreenTheme of(BuildContext context) => Theme.of(context).extension<FormScreenTheme>() ?? light;

  /// Etiqueta en mayúsculas de sección o de campo (12, semibold, espaciado amplio).
  TextStyle labelStyle(Color color) => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: color);

  /// Etiqueta de un campo dentro de un renglón (11).
  TextStyle get innerLabelStyle => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: fieldLabel);

  /// Borde del campo según el foco y el error; con foco, halo rosa suave.
  BoxDecoration fieldDecoration({required bool focused, bool error = false, bool inner = false}) => BoxDecoration(
        color: inner && !focused ? innerField : surface,
        borderRadius: BorderRadius.circular(inner ? innerRadius : radius),
        border: Border.all(color: error || focused ? accent : border),
        boxShadow: [
          if (focused) BoxShadow(color: accent.withValues(alpha: 0.10), spreadRadius: inner ? 2 : 4),
          if (!inner && !focused) ...shadow,
        ],
      );

  @override
  FormScreenTheme copyWith() => this;

  @override
  FormScreenTheme lerp(covariant FormScreenTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FormScreenTheme(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      innerField: c(innerField, other.innerField),
      border: c(border, other.border),
      dashedBorder: c(dashedBorder, other.dashedBorder),
      sectionLabel: c(sectionLabel, other.sectionLabel),
      fieldLabel: c(fieldLabel, other.fieldLabel),
      text: c(text, other.text),
      title: c(title, other.title),
      hint: c(hint, other.hint),
      icon: c(icon, other.icon),
      accent: c(accent, other.accent),
      accentStrong: c(accentStrong, other.accentStrong),
      accentPressed: c(accentPressed, other.accentPressed),
      accentSoft: c(accentSoft, other.accentSoft),
      accentSoftBorder: c(accentSoftBorder, other.accentSoftBorder),
      badgeBackground: c(badgeBackground, other.badgeBackground),
      badgeBorder: c(badgeBorder, other.badgeBorder),
      badgeText: c(badgeText, other.badgeText),
      pillNeutral: c(pillNeutral, other.pillNeutral),
      pillNeutralText: c(pillNeutralText, other.pillNeutralText),
      deleteIcon: c(deleteIcon, other.deleteIcon),
      shadow: t < 0.5 ? shadow : other.shadow,
      floatShadow: t < 0.5 ? floatShadow : other.floatShadow,
    );
  }
}

/// Borde punteado redondeado (sin dependencias): "Agregar Renglón".
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DashedBorderPainter({required this.color, required this.radius, this.strokeWidth = 2, this.dash = 6, this.gap = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}
