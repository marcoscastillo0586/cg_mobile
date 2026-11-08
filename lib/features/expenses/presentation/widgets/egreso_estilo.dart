import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/form_screen_theme.dart';

/// Estilo visual de "Nuevo Egreso" según el diseño de Stitch (solo esta pantalla y sus widgets).
/// No reemplaza a [FormScreenTheme] ni al tema global: en oscuro se mantienen los colores de siempre.
/// Los colores que no están en [AppColors] (tonos de la paleta del diseño) son constantes locales.
@immutable
class EgresoEstilo {
  /// pink-600: final del degradado del banner incompleto.
  static const Color _pink600 = Color(0xFFDB2777);

  /// violet-800: final del degradado del banner completo.
  static const Color _violet800 = Color(0xFF5B21B6);

  /// slate-100: borde inferior de la barra superior.
  static const Color _slate100 = AppColors.slate100;

  final bool oscuro;
  final FormScreenTheme t;

  const EgresoEstilo._(this.oscuro, this.t);

  static EgresoEstilo of(BuildContext context) =>
      EgresoEstilo._(Theme.of(context).brightness == Brightness.dark, FormScreenTheme.of(context));

  // ---------- Barra superior ----------

  Color get barraFondo => oscuro ? t.background.withValues(alpha: 0.9) : AppColors.lightSurface;
  Color get barraBorde => oscuro ? t.border.withValues(alpha: 0.6) : _slate100;
  TextStyle get barraTitulo => TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: t.title);

  // ---------- Banner "Escanear" (incompleto = rosa, completo = índigo) ----------

  static const double bannerIcono = 48;

  double bannerRadio(bool completo) => completo ? 24 : 16;
  double bannerIconoRadio(bool completo) => completo ? 16 : 12;

  LinearGradient bannerDegradado(bool completo) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: completo
            ? const [AppColors.primary, AppColors.indigo700, _violet800]
            : const [AppColors.brand500, AppColors.brand600, _pink600],
      );

  List<BoxShadow> bannerSombra(bool completo) => [
        BoxShadow(
          color: completo ? AppColors.primary.withValues(alpha: 0.20) : AppColors.brand600.withValues(alpha: 0.12),
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  /// Texto del botón blanco del banner.
  Color bannerBotonTexto(bool completo) => completo ? AppColors.indigo700 : AppColors.brand600;

  // ---------- Etiquetas de sección ----------

  /// "CUENTA DE ORIGEN", "RENGLONES"…: 12, 700, mayúsculas con espaciado amplio, slate-500.
  TextStyle get etiqueta => oscuro
      ? t.labelStyle(t.sectionLabel)
      : const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.lightTextSecondary);

  // ---------- Sombras ----------

  /// Tarjeta sutil (`card-subtle`).
  List<BoxShadow> get sombraTarjeta => oscuro
      ? t.shadow
      : const [
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 10, spreadRadius: -2, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x080F172A), blurRadius: 3, spreadRadius: -1, offset: Offset(0, 1)),
        ];

  // ---------- Campos principales (concepto general) ----------

  /// Caja del campo: blanco, radio 16, borde slate-200 (2 px vacío, 1 px con texto), foco índigo con
  /// halo suave y borde rosa si falta. En oscuro, la caja de siempre.
  BoxDecoration campo({required bool focused, required bool error, required bool vacio}) {
    if (oscuro) return t.fieldDecoration(focused: focused, error: error);
    final color = error ? AppColors.brand500 : (focused ? AppColors.primary : AppColors.lightBorder);
    return BoxDecoration(
      color: AppColors.lightSurface,
      borderRadius: BorderRadius.circular(FormScreenTheme.radius),
      border: Border.all(color: color, width: vacio ? 2 : 1),
      boxShadow: [
        if (focused) BoxShadow(color: (error ? AppColors.brand500 : AppColors.primary).withValues(alpha: 0.10), spreadRadius: 4),
        if (!focused) ...sombraTarjeta,
      ],
    );
  }

  TextStyle get campoTexto =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: oscuro ? t.text : AppColors.lightTextPrimary);

  /// Recuadro de 28 px del ícono del campo: gris vacío, índigo con texto.
  static const double campoIcono = 28;
  Color campoIconoFondo({required bool vacio}) =>
      oscuro ? t.pillNeutral : (vacio ? AppColors.slate100 : AppColors.indigo50);
  Color campoIconoColor({required bool vacio}) =>
      oscuro ? t.icon : (vacio ? AppColors.lightTextSecondary : AppColors.primary);

  // ---------- Fecha: control segmentado "Hoy / Ayer" ----------

  Color get segmentoFondo => oscuro ? t.pillNeutral : AppColors.slate100;

  /// Activa: rosa con texto blanco (incompleto) o blanca con texto índigo (completo).
  Color segmentoActivoFondo(bool completo) =>
      oscuro ? t.accentSoft : (completo ? AppColors.lightSurface : AppColors.brand600);
  Color segmentoActivoTexto(bool completo) =>
      oscuro ? t.accentStrong : (completo ? AppColors.indigo700 : AppColors.lightSurface);
  Color get segmentoInactivoTexto => oscuro ? t.pillNeutralText : AppColors.slate600;
  List<BoxShadow> get segmentoActivoSombra =>
      oscuro ? const [] : const [BoxShadow(color: Color(0x140F172A), blurRadius: 2, offset: Offset(0, 1))];

  /// Texto de la fecha (14, 700) e ícono de la derecha (slate-400).
  TextStyle get fechaTexto =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: oscuro ? t.text : AppColors.lightTextPrimary);
  Color get fechaIconoDerecha => oscuro ? t.text : AppColors.slate400;

  // ---------- Renglones ----------

  BoxDecoration get tarjeta => BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(FormScreenTheme.radius),
        border: Border.all(color: oscuro ? t.border : AppColors.lightBorder),
        boxShadow: sombraTarjeta,
      );

  Color get insigniaFondo => oscuro ? t.badgeBackground : AppColors.indigo50;
  Color get insigniaBorde => oscuro ? t.badgeBorder : AppColors.indigo100;
  Color get insigniaTexto => oscuro ? t.badgeText : AppColors.indigo700;

  /// Línea bajo la cabecera del renglón (slate-100).
  Color get separador => oscuro ? t.border : AppColors.slate100;

  /// Papelera: slate-400; al presionar, rosa sobre rosa claro.
  Color get papelera => oscuro ? t.deleteIcon : AppColors.slate400;
  Color get papeleraActiva => oscuro ? t.accent : AppColors.brand500;
  Color get papeleraActivaFondo => oscuro ? t.accentSoft : AppColors.brand50;

  /// "CONCEPTO DEL RENGLÓN", "MONTO", "CATEGORÍA": 11, 700, slate-500.
  TextStyle get etiquetaInterna => oscuro
      ? t.innerLabelStyle
      : const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.lightTextSecondary);

  /// Campo dentro del renglón: slate-50, borde slate-200, radio 12; con foco blanco, borde índigo y halo de 2 px.
  BoxDecoration campoInterno({required bool focused, required bool error}) {
    if (oscuro) return t.fieldDecoration(focused: focused, error: error, inner: true);
    final color = error ? AppColors.brand500 : (focused ? AppColors.primary : AppColors.lightBorder);
    return BoxDecoration(
      color: focused ? AppColors.lightSurface : AppColors.lightBg,
      borderRadius: BorderRadius.circular(FormScreenTheme.innerRadius),
      border: Border.all(color: color),
      boxShadow: [
        if (focused) BoxShadow(color: (error ? AppColors.brand500 : AppColors.primary).withValues(alpha: 0.10), spreadRadius: 2),
      ],
    );
  }

  TextStyle textoInterno(double size, FontWeight peso) =>
      TextStyle(fontSize: size, fontWeight: peso, color: oscuro ? t.text : AppColors.slate800);
  Color get iconoInterno => oscuro ? t.icon : AppColors.slate400;

  // ---------- "Agregar Renglón" ----------

  Color get agregarBorde => oscuro ? t.dashedBorder : AppColors.slate300;
  Color get agregarFondo => oscuro ? t.surface.withValues(alpha: 0.6) : AppColors.lightSurface.withValues(alpha: 0.7);
  Color get agregarTexto => oscuro ? t.pillNeutralText : AppColors.primary;
  Color get agregarCirculo => oscuro ? t.pillNeutral : AppColors.indigo50;
  Color get agregarToque => oscuro ? t.accentSoft : AppColors.indigo50;

  // ---------- Total del gasto (incompleto = oscuro, completo = verde claro) ----------

  /// slate-900 → slate-800.
  static const List<Color> totalOscuroDegradado = [AppColors.lightTextPrimary, AppColors.slate800];
  static const List<BoxShadow> totalOscuroSombra = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 15, spreadRadius: -3, offset: Offset(0, 10)),
  ];

  /// emerald-50 → teal-50 (60 %) → emerald-50 (80 %), borde emerald-200 (90 %).
  static const List<Color> totalVerdeDegradado = [Color(0xFFECFDF5), Color(0x99F0FDFA), Color(0xCCECFDF5)];
  static const Color totalVerdeBorde = Color(0xE6A7F3D0);

  /// emerald-700: importe del total completo; también el botón completo presionado.
  static const Color emerald700 = Color(0xFF047857);

  // ---------- Botón inferior "Registrar Gasto" ----------

  /// Rojo (rose-600) hasta completar los obligatorios; verde (emerald-600) al completarlos.
  Color botonFondo({required bool completo, required bool presionado}) => completo
      ? (presionado ? emerald700 : AppColors.emeraldDark)
      : (presionado ? t.accentPressed : t.accentStrong);

  List<BoxShadow> botonSombra(bool completo) {
    final c = completo ? AppColors.emeraldDark : AppColors.brand600;
    return [
      BoxShadow(color: c.withValues(alpha: 0.30), blurRadius: 25, spreadRadius: -5, offset: const Offset(0, 10)),
      BoxShadow(color: c.withValues(alpha: 0.20), blurRadius: 10, spreadRadius: -6, offset: const Offset(0, 8)),
    ];
  }

  /// Barra inferior blanca con borde arriba y sombra hacia arriba; en oscuro, null (se usa el desvanecido de siempre).
  BoxDecoration? get barraInferior => oscuro
      ? null
      : BoxDecoration(
          color: AppColors.lightSurface.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: AppColors.lightBorder.withValues(alpha: 0.9))),
          boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, spreadRadius: -4, offset: Offset(0, -8))],
        );

  /// Asterisco de obligatorio (rose-500).
  Color get obligatorio => oscuro ? t.accent : AppColors.brand500;

  // ---------- Tarjetas de cuenta ----------

  /// slate-700: saldo de una cuenta no seleccionada.
  static const Color _slate700 = Color(0xFF334155);

  static const double cuentaAnchoMin = 215;
  static const double cuentaAnchoMax = 260;
  static const double cuentaRelleno = 14;
  static const double cuentaCheck = 20;

  /// Seleccionada: índigo (en oscuro, el acento de siempre).
  Color get cuentaSeleccion => oscuro ? t.accent : AppColors.primary;
  Color get cuentaBorde => oscuro ? t.border : AppColors.lightBorder;

  List<BoxShadow> cuentaSombra(bool seleccionada) => oscuro
      ? t.shadow
      : seleccionada
          ? const [BoxShadow(color: Color(0x294F46E5), blurRadius: 14, spreadRadius: -2, offset: Offset(0, 4))]
          : sombraTarjeta;

  TextStyle cuentaNombre(bool seleccionada) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: oscuro ? (seleccionada ? t.title : t.fieldLabel) : (seleccionada ? AppColors.slate600 : AppColors.lightTextSecondary),
      );

  TextStyle cuentaSaldo(bool seleccionada, {required bool negativo}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: negativo
            ? t.accentStrong
            : oscuro
                ? t.text
                : (seleccionada ? AppColors.lightTextPrimary : _slate700),
      );
}
