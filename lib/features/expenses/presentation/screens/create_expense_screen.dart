import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../../core/theme/form_screen_theme.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/bottom_safe_area.dart';
import '../../../../core/widgets/account_picker.dart';
import '../../../../routes/app_routes.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../../../core/network/server_reachability.dart';
import '../providers/expense_form_notifier.dart';
import '../providers/expense_form_state.dart';
import '../widgets/egreso_cuenta_carousel.dart';
import '../widgets/egreso_field_box.dart';
import '../widgets/renglon_gasto_card.dart';
import '../../../../l10n/l10n.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  /// Alta rechazada a corregir (desde "Pendientes y rechazados").
  final CorrectionSource? correction;
  const CreateExpenseScreen({super.key, this.correction});

  @override
  ConsumerState<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _conceptoGeneralController = TextEditingController();
  final _conceptoGeneralFocus = FocusNode();

  /// Se intentó registrar sin concepto general (obligatorio): el campo queda marcado hasta completarlo.
  bool _conceptoGeneralFalta = false;

  @override
  void initState() {
    super.initState();
    // Se muestra enseguida con lo guardado; con conexión se actualiza al llegar lo del servidor.
    ref.read(syncControllerProvider.notifier).refreshIfOnline().then((_) {
      if (mounted) ref.read(expenseFormNotifierProvider.notifier).recargarCatalogo();
    });
    _conceptoGeneralController.addListener(() {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .setConceptoGeneral(_conceptoGeneralController.text);
      if (_conceptoGeneralFalta && _conceptoGeneralController.text.trim().isNotEmpty) {
        setState(() => _conceptoGeneralFalta = false);
      }
    });
    final c = widget.correction;
    if (c != null) {
      ref.read(expenseFormNotifierProvider.notifier).prefill(c).then((_) {
        if (mounted) _conceptoGeneralController.text = c.concept;
      });
    }
  }

  @override
  void dispose() {
    _conceptoGeneralController.dispose();
    _conceptoGeneralFocus.dispose();
    super.dispose();
  }

  void _seleccionarFecha(BuildContext context) async {
    final estado = ref.read(expenseFormNotifierProvider);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: estado.fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: context.l10n.expenseDate,
    );

    if (seleccionada != null) {
      AppFeedback.selection();
      ref.read(expenseFormNotifierProvider.notifier).setFecha(seleccionada);
    }
  }

  void _abrirCapturaTicket(BuildContext context) async {
    final result = await context.push<TicketParseResult>(AppRoutes.scanTicket);
    if (result != null && mounted) {
      ref.read(expenseFormNotifierProvider.notifier).aplicarResultadoTicket(result);
      // Ticket QR: el concepto general sale del ticket (comercio + sucursal).
      if (result.qr != null) _conceptoGeneralController.text = ref.read(expenseFormNotifierProvider).conceptoGeneral;
    }
  }

  /// Espaciado de diseño alrededor del botón inferior fijo.
  static const _pieBoton = EdgeInsets.all(16);

  /// Evita un segundo guardado mientras se espera la respuesta del servidor.
  bool _guardando = false;

  /// Píldoras "Hoy" / "Ayer": cargan esa fecha.
  void _fechaRapida(int diasAtras) {
    AppFeedback.selection();
    ref.read(expenseFormNotifierProvider.notifier).setFecha(DateTime.now().subtract(Duration(days: diasAtras)));
  }

  void _guardarGasto() async {
    if (_guardando) return;
    // Concepto general obligatorio: se valida en la pantalla antes de registrar.
    if (_conceptoGeneralController.text.trim().isEmpty) {
      setState(() => _conceptoGeneralFalta = true);
      _conceptoGeneralFocus.requestFocus();
      AppFeedback.showError(context, context.l10n.fillConceptField);
      return;
    }
    _guardando = true;
    try {
      await _guardarGastoAhora();
    } finally {
      _guardando = false;
    }
  }

  Future<void> _guardarGastoAhora() async {
    final st = ref.read(expenseFormNotifierProvider);
    final cuenta = st.cuentaSeleccionada;
    // Sin fondos se puede guardar igual (el dinero puede no estar cargado), pero se avisa y se confirma.
    // Solo con conexión (saldo recién traído del servidor); sin conexión se guarda sin diálogos.
    if (cuenta != null && st.fondosInsuficientes && !ServerReachability.offline.value) {
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.balanceWillNegative),
          content: Text(negativeBalanceText(cuenta, st.totalCents, context.l10n)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
            TextButton(
              key: const ValueKey('guardar-igual'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.saveAnyway),
            ),
          ],
        ),
      );
      if (seguir != true || !mounted) return;
    }
    final esQr = st.ticketParseResult?.qr != null;
    final notifier = ref.read(expenseFormNotifierProvider.notifier);
    final ok = await notifier.guardarEgreso();
    if (!mounted) return;
    if (ok && esQr) {
      // Quedó registrado en el servidor y ya se trajo al celular; la sincronización trae el resto.
      unawaited(ref.read(syncControllerProvider.notifier).sync());
      final localError = notifier.ticketLocalCopyError;
      if (notifier.ticketAlreadyRegistered) {
        AppFeedback.showInfo(context, context.l10n.ticketAlreadyRegistered);
      } else if (localError != null) {
        AppFeedback.showError(context, context.l10n.ticketRecordedNotOnPhoneYet(describeWithCode(localError, context.l10n)));
      } else {
        AppFeedback.showSuccess(context, context.l10n.ticketRecordedServer);
      }
      context.pop(true);
    } else if (ok) {
      if (await afterLocalWrite(context, ref, context.l10n.expense) && mounted) context.pop(true);
    } else {
      final error = ref.read(expenseFormNotifierProvider).error;
      if (error == null) return;
      final hint = esQr && error is NetworkException
          ? (context.l10n.confirmingQrTicketRequiresConnection)
          : '';
      AppFeedback.showError(context, describeWithCode(error, context.l10n) + hint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseFormNotifierProvider);
    final t = FormScreenTheme.of(context);

    if (state.isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == ExpenseFormStatus.error) {
      return LocalDataError(error: state.error!, onRetry: ref.read(expenseFormNotifierProvider.notifier).inicializar);
    }

    final categorias = state.categorias;
    final sugerenciasConceptos = state.conceptos;
    final formatoFecha = AppDateUtils.formatDate(state.fecha);
    final cuenta = state.cuentaSeleccionada;
    final moneda = cuenta?.currency ?? Currency.ars;
    final totalFormateado = Money.format(state.totalCents, currency: moneda);
    // Tarjeta del total: el símbolo va aparte, más chico.
    final totalSinSimbolo = totalFormateado.replaceFirst('${moneda.symbol} ', '');

    final tituloModulo = widget.correction != null
        ? (context.l10n.correctExpense)
        : (context.l10n.newExpense);
    final textoBoton = (context.l10n.registerExpense(totalFormateado));

    const lateral = 20.0;
    // Espacio del botón fijo (con el margen del sistema): la tarjeta del total no queda oculta detrás.
    final pie = BottomActionArea.reservedHeight(context, childHeight: FormScreenTheme.bottomButtonHeight, padding: _pieBoton);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 60,
        shape: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.6))),
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 30, color: t.text),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tituloModulo,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: t.title),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _EscanearPill(onTap: () => _abrirCapturaTicket(context)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: 16, bottom: pie + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cuenta de origen (carrusel hasta los bordes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: lateral),
                  child: _Etiqueta(context.l10n.sourceAccount, color: t.sectionLabel),
                ),
                const SizedBox(height: 10),
                EgresoCuentaCarousel(
                  cuentas: state.cuentas,
                  selectedId: state.selectedCuentaId,
                  sidePadding: lateral,
                  onSelect: (id) => ref.read(expenseFormNotifierProvider.notifier).setCuenta(id),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: lateral),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Concepto general (obligatorio)
                      _Etiqueta(context.l10n.generalConcept, color: t.fieldLabel, obligatorio: true),
                      const SizedBox(height: 6),
                      EgresoFieldBox(
                        focusNode: _conceptoGeneralFocus,
                        error: _conceptoGeneralFalta,
                        child: TextField(
                          controller: _conceptoGeneralController,
                          focusNode: _conceptoGeneralFocus,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
                          decoration: EgresoFieldBox.input(
                            hint: context.l10n.eGSupermarketBookstore,
                            hintColor: t.hint,
                            prefixIcon: Icon(Icons.home_outlined, size: 20, color: t.icon),
                          ),
                        ),
                      ),
                      if (_conceptoGeneralFalta) ...[
                        const SizedBox(height: 4),
                        Text(context.l10n.fillConceptField, style: TextStyle(fontSize: 11, color: t.accentStrong)),
                      ],
                      const SizedBox(height: 14),

                      // 3. Fecha, con píldoras "Hoy" y "Ayer"
                      Row(
                        children: [
                          Expanded(child: _Etiqueta(context.l10n.date, color: t.fieldLabel)),
                          _Pildora(
                            texto: context.l10n.today,
                            fondo: t.accentSoft,
                            color: t.accentStrong,
                            peso: FontWeight.w600,
                            onTap: () => _fechaRapida(0),
                          ),
                          const SizedBox(width: 6),
                          _Pildora(
                            texto: context.l10n.yesterday,
                            fondo: t.pillNeutral,
                            color: t.pillNeutralText,
                            peso: FontWeight.w500,
                            onTap: () => _fechaRapida(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _seleccionarFecha(context),
                          borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                          child: EgresoFieldBox(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 20, color: t.icon),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      formatoFecha,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text),
                                    ),
                                  ),
                                  Icon(Icons.calendar_month_rounded, size: 18, color: t.text),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Banner Feedback de Lectura de Ticket
                      if (state.ticketParseResult != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (state.ticketParseResult?.tieneDiferenciaTotal == true)
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : AppColors.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                            border: Border.all(
                              color: (state.ticketParseResult?.tieneDiferenciaTotal == true)
                                  ? AppColors.amber.withValues(alpha: 0.5)
                                  : AppColors.emerald.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (state.ticketParseResult?.tieneDiferenciaTotal == true)
                                    ? Icons.warning_amber_rounded
                                    : Icons.receipt_long_rounded,
                                color: (state.ticketParseResult?.tieneDiferenciaTotal == true)
                                    ? AppColors.amberDark
                                    : AppColors.emerald,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _ticketFeedback(state.ticketParseResult!, context.l10n),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (state.ticketParseResult?.tieneDiferenciaTotal == true)
                                        ? AppColors.amberDark
                                        : AppColors.emeraldDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  ref.read(expenseFormNotifierProvider.notifier).limpiarItemsTicket();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. Renglones
                      _Etiqueta(context.l10n.lines2, color: t.sectionLabel),
                      const SizedBox(height: 14),

                      ...state.renglones.asMap().entries.map((entry) {
                        final index = entry.key;
                        final renglon = entry.value;

                        return RenglonGastoCard(
                          key: ValueKey(renglon.id),
                          index: index,
                          renglon: renglon,
                          categorias: categorias,
                          sugerenciasConcepto: sugerenciasConceptos,
                          canDelete: state.puedeEliminarRenglon,
                          onEliminar: () {
                            AppFeedback.medium();
                            ref
                                .read(expenseFormNotifierProvider.notifier)
                                .eliminarRenglon(renglon.id);
                          },
                          onConceptoChanged: (nuevoConcepto) {
                            ref
                                .read(expenseFormNotifierProvider.notifier)
                                .actualizarConcepto(renglon.id, nuevoConcepto);
                          },
                          onMontoChanged: (nuevoMonto) {
                            ref
                                .read(expenseFormNotifierProvider.notifier)
                                .actualizarMonto(renglon.id, nuevoMonto);
                          },
                          onCategoriaChanged: (nuevaCatId) {
                            AppFeedback.selection();
                            ref
                                .read(expenseFormNotifierProvider.notifier)
                                .actualizarCategoria(renglon.id, nuevaCatId);
                          },
                        );
                      }),

                      // 5. Agregar renglón (borde punteado)
                      _AgregarRenglonButton(
                        onTap: () {
                          AppFeedback.light();
                          ref.read(expenseFormNotifierProvider.notifier).agregarRenglon();
                        },
                      ),
                      const SizedBox(height: 24),

                      // 6. Total del gasto
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.accentSoft.withValues(alpha: 0.8), t.surface, t.accentSoft.withValues(alpha: 0.5)],
                          ),
                          borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                          border: Border.all(color: t.accentSoftBorder.withValues(alpha: 0.9)),
                          boxShadow: t.shadow,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.expenseTotal.toUpperCase(),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: t.text),
                                  ),
                                  Text(
                                    context.l10n.linesCount(state.cantidadRenglones),
                                    style: TextStyle(fontSize: 12, color: t.fieldLabel),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      moneda.symbol,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.accent),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      totalSinSimbolo,
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: t.accentStrong),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Aviso de fondos antes de guardar (saldo local, ya descuenta lo pendiente).
                      if (cuenta != null && state.fondosInsuficientes)
                        FundsWarning(cuenta: cuenta, amountCents: state.totalCents),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 7. Botón inferior fijo, por encima de la barra del sistema; el contenido se desvanece por detrás.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomActionArea(
              padding: _pieBoton,
              fadeColor: t.background,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                  boxShadow: t.floatShadow,
                ),
                child: ElevatedButton(
                  key: const ValueKey('guardar-egreso'),
                  onPressed: state.isSubmitting ? null : _guardarGasto,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(FormScreenTheme.bottomButtonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FormScreenTheme.radius),
                    ),
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.pressed) ? t.accentPressed : t.accentStrong,
                    ),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined, size: 20),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                textoBoton,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta en mayúsculas (12, semibold, espaciado amplio); con asterisco rosa si es obligatoria.
class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final bool obligatorio;
  const _Etiqueta(this.texto, {required this.color, this.obligatorio = false});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    return Text.rich(
      TextSpan(
        text: texto.toUpperCase(),
        children: [if (obligatorio) TextSpan(text: ' *', style: TextStyle(color: t.accent))],
      ),
      style: t.labelStyle(color),
    );
  }
}

/// Píldora de fecha rápida ("Hoy", "Ayer").
class _Pildora extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  final FontWeight peso;
  final VoidCallback onTap;
  const _Pildora({required this.texto, required this.fondo, required this.color, required this.peso, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fondo,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: peso, color: color)),
        ),
      ),
    );
  }
}

/// Botón "Escanear" de la barra superior (píldora rosa claro).
class _EscanearPill extends StatelessWidget {
  final VoidCallback onTap;
  const _EscanearPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    return Tooltip(
      message: context.l10n.scanReceipt,
      child: Material(
        color: t.accentSoft,
        shape: StadiumBorder(side: BorderSide(color: t.accentSoftBorder.withValues(alpha: 0.9))),
        elevation: 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner_outlined, size: 16, color: t.accentStrong),
                const SizedBox(width: 6),
                Text(
                  context.l10n.scan2,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: -0.2, color: t.accentStrong),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Agregar Renglón": ancho completo, borde punteado e ícono "+".
class _AgregarRenglonButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AgregarRenglonButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    final radio = BorderRadius.circular(FormScreenTheme.radius);
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(color: t.dashedBorder, radius: FormScreenTheme.radius),
      child: Material(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          splashColor: t.accentSoft,
          highlightColor: t.accentSoft.withValues(alpha: 0.4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: t.pillNeutral, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 14, color: t.pillNeutralText),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.addLine,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.3, color: t.pillNeutralText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumen de la lectura del ticket: suma de renglones contra el total impreso, si se leyó.
String _ticketFeedback(TicketParseResult r, AppLocalizations l) {
  final suma = Money.format(r.sumaRenglonesCents);
  final total = r.totalDetectadoCents;
  if (total == null) return l.ticketSumNoTotal(suma);
  return r.tieneDiferenciaTotal
      ? l.ticketSumDiffers(suma, Money.format(total), Money.format(r.sumaRenglonesCents - total))
      : l.ticketReadSumTotal(suma, Money.format(total));
}
