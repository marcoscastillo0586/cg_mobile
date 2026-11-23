import 'dart:async';
import 'dart:ui' show ImageFilter;
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
import '../../data/tickets_repository.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../../../../core/network/server_reachability.dart';
import '../providers/expense_form_notifier.dart';
import '../providers/expense_form_state.dart';
import '../widgets/egreso_cuenta_carousel.dart';
import '../widgets/egreso_estilo.dart';
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
    // Se muestra enseguida con lo guardado; con conexión se actualiza al llegar lo del servidor. Después del
    // primer cuadro: cambiar un provider mientras se arma la pantalla no está permitido.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await ref.read(expenseFormNotifierProvider.notifier).recargarCatalogo();
    });
    _conceptoGeneralController.addListener(() {
      ref.read(expenseFormNotifierProvider.notifier).setConceptoGeneral(_conceptoGeneralController.text);
      if (_conceptoGeneralFalta && _conceptoGeneralController.text.trim().isNotEmpty) {
        setState(() => _conceptoGeneralFalta = false);
      }
    });
    final c = widget.correction;
    if (c != null) {
      Future.microtask(() => ref.read(expenseFormNotifierProvider.notifier).prefill(c)).then((_) {
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

  /// Verificando el servidor antes de abrir "Escanear ticket" (evita toques repetidos).
  bool _verificandoServidor = false;

  /// "Escanear ticket" solo funciona con el servidor (lectura con IA / QR): se verifica al tocar el
  /// banner. Sin conexión se avisa y no se abre; queda la carga manual, que se guarda en el celular.
  void _abrirCapturaTicket(BuildContext context) async {
    if (_verificandoServidor) return;
    setState(() => _verificandoServidor = true);
    final disponible = await ref.read(ticketsRepositoryProvider).serverAvailable();
    if (!mounted) return;
    setState(() => _verificandoServidor = false);
    if (!disponible) {
      AppFeedback.selection();
      await showDialog<void>(
        context: this.context,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('escanear-sin-conexion'),
          icon: const Icon(Icons.cloud_off_rounded),
          content: Text(ctx.l10n.featureUnavailableOffline, textAlign: TextAlign.center),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
        ),
      );
      return;
    }
    if (!mounted) return;
    final result = await this.context.push<TicketParseResult>(AppRoutes.scanTicket);
    if (result != null && mounted) {
      ref.read(expenseFormNotifierProvider.notifier).aplicarResultadoTicket(result);
      // Ticket QR: el concepto general sale del ticket (comercio + sucursal).
      if (result.qr != null) _conceptoGeneralController.text = ref.read(expenseFormNotifierProvider).conceptoGeneral;
    }
  }

  /// Espaciado de diseño alrededor del botón inferior fijo.
  static const _pieBoton = EdgeInsets.fromLTRB(16, 12, 16, 12);

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
    if (!await _confirmarSaldoNegativo(st) || !mounted) return;
    final esQr = st.ticketParseResult?.qr != null;
    final notifier = ref.read(expenseFormNotifierProvider.notifier);
    final ok = await notifier.guardarEgreso();
    if (!mounted) return;
    if (!ok) return _mostrarError(esQr);
    if (esQr) return _ticketQrRegistrado(notifier);
    if (await afterLocalWrite(context, ref, context.l10n.expense) && mounted) context.pop(true);
  }

  /// Sin fondos se puede guardar igual (el dinero puede no estar cargado), pero se avisa y se confirma.
  /// Solo con conexión (saldo recién traído del servidor); sin conexión se guarda sin diálogos.
  Future<bool> _confirmarSaldoNegativo(ExpenseFormState st) async {
    final cuenta = st.cuentaSeleccionada;
    if (cuenta == null || !st.fondosInsuficientes || ServerReachability.offline.value) return true;
    final seguir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.balanceWillNegative),
        content: Text(negativeBalanceText(cuenta, st.totalCents, context.l10n)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(key: const ValueKey('guardar-igual'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.saveAnyway)),
        ],
      ),
    );
    return seguir == true;
  }

  /// Ticket QR: quedó registrado en el servidor y ya se trajo al celular; la sincronización trae el resto.
  void _ticketQrRegistrado(ExpenseFormNotifier notifier) {
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
  }

  void _mostrarError(bool esQr) {
    final error = ref.read(expenseFormNotifierProvider).error;
    if (error == null) return;
    final hint = esQr && error is NetworkException ? context.l10n.confirmingQrTicketRequiresConnection : '';
    AppFeedback.showError(context, describeWithCode(error, context.l10n) + hint);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseFormNotifierProvider);
    final t = FormScreenTheme.of(context);
    final e = EgresoEstilo.of(context);

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
    final cuenta = state.cuentaSeleccionada;
    final moneda = cuenta?.currency ?? Currency.ars;
    final totalFormateado = Money.format(state.totalCents, currency: moneda);

    final tituloModulo = widget.correction != null ? (context.l10n.correctExpense) : (context.l10n.newExpense);
    final textoBoton = (context.l10n.registerExpense(totalFormateado));
    final conceptoVacio = state.conceptoGeneral.trim().isEmpty;

    const lateral = 16.0;
    // Espacio del botón fijo (con el margen del sistema): la tarjeta del total no queda oculta detrás.
    final pie = BottomActionArea.reservedHeight(context, childHeight: FormScreenTheme.bottomButtonHeight, padding: _pieBoton);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: e.barraFondo,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 60,
        shape: Border(bottom: BorderSide(color: e.barraBorde)),
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 30, color: t.text),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(tituloModulo, style: e.barraTitulo),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: 16, bottom: pie + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Banner "Escanear" (rosa incompleto, índigo completo): abre la captura de ticket.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: lateral),
                  child: _EscanearBanner(
                    completo: state.isFormComplete,
                    verificando: _verificandoServidor,
                    onTap: () => _abrirCapturaTicket(context),
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Cuenta de origen (carrusel hasta los bordes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: lateral),
                  child: _Etiqueta(context.l10n.sourceAccount, color: t.sectionLabel, estilo: e.etiqueta),
                ),
                const SizedBox(height: 10),
                EgresoCuentaCarousel(
                  cuentas: state.cuentas,
                  selectedId: state.selectedCuentaId,
                  sidePadding: lateral,
                  onSelect: (id) => ref.read(expenseFormNotifierProvider.notifier).setCuenta(id),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: lateral),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Concepto general (obligatorio)
                      _Etiqueta(context.l10n.generalConcept, color: t.fieldLabel, obligatorio: true, estilo: e.etiqueta),
                      const SizedBox(height: 8),
                      EgresoFieldBox(
                        focusNode: _conceptoGeneralFocus,
                        error: _conceptoGeneralFalta,
                        stitch: true,
                        vacio: conceptoVacio,
                        child: TextField(
                          controller: _conceptoGeneralController,
                          focusNode: _conceptoGeneralFocus,
                          textCapitalization: TextCapitalization.sentences,
                          style: e.campoTexto,
                          decoration: EgresoFieldBox.input(
                            hint: context.l10n.eGSupermarketBookstore,
                            hintColor: t.hint,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 14, right: 10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: EgresoEstilo.campoIcono,
                                height: EgresoEstilo.campoIcono,
                                decoration: BoxDecoration(
                                  color: e.campoIconoFondo(vacio: conceptoVacio),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.storefront_outlined, size: 16, color: e.campoIconoColor(vacio: conceptoVacio)),
                              ),
                            ),
                          ).copyWith(
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                          ),
                        ),
                      ),
                      if (_conceptoGeneralFalta) ...[
                        const SizedBox(height: 4),
                        Text(context.l10n.fillConceptField, style: TextStyle(fontSize: 11, color: t.accentStrong)),
                      ],
                      const SizedBox(height: 20),

                      // 3. Fecha, con píldoras "Hoy" y "Ayer"
                      _FechaSeccion(
                        fecha: state.fecha,
                        completo: state.isFormComplete,
                        onDiasAtras: _fechaRapida,
                        onElegir: () => _seleccionarFecha(context),
                      ),
                      const SizedBox(height: 20),

                      // Banner Feedback de Lectura de Ticket
                      if (state.ticketParseResult != null) ...[
                        _TicketBanner(
                          result: state.ticketParseResult!,
                          onClose: () => ref.read(expenseFormNotifierProvider.notifier).limpiarItemsTicket(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. Renglones
                      _Etiqueta(context.l10n.lines2, color: t.sectionLabel, estilo: e.etiqueta),
                      const SizedBox(height: 12),

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
                            ref.read(expenseFormNotifierProvider.notifier).eliminarRenglon(renglon.id);
                          },
                          onConceptoChanged: (nuevoConcepto) {
                            ref.read(expenseFormNotifierProvider.notifier).actualizarConcepto(renglon.id, nuevoConcepto);
                          },
                          onMontoChanged: (nuevoMonto) {
                            ref.read(expenseFormNotifierProvider.notifier).actualizarMonto(renglon.id, nuevoMonto);
                          },
                          onCategoriaChanged: (nuevaCatId) {
                            AppFeedback.selection();
                            ref.read(expenseFormNotifierProvider.notifier).actualizarCategoria(renglon.id, nuevaCatId);
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
                      const SizedBox(height: 20),

                      // 6. Total del gasto y aviso de fondos antes de guardar.
                      _SeccionTotal(state: state, moneda: moneda, totalFormateado: totalFormateado),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 7. Botón inferior fijo, por encima de la barra del sistema, sobre una barra blanca con borde
          //    (en tema oscuro, el contenido se desvanece por detrás como siempre).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: e.barraInferior ?? const BoxDecoration(),
              child: BottomActionArea(
                padding: _pieBoton,
                fadeColor: e.oscuro ? t.background : null,
                child: _BotonGuardar(
                  completo: state.isFormComplete,
                  guardando: state.isSubmitting,
                  texto: textoBoton,
                  onPressed: _guardarGasto,
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

  /// Estilo del diseño de Stitch (secciones ya migradas); sin él, el de siempre.
  final TextStyle? estilo;
  const _Etiqueta(this.texto, {required this.color, this.obligatorio = false, this.estilo});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    return Text.rich(
      TextSpan(
        text: texto.toUpperCase(),
        children: [
          if (obligatorio)
            TextSpan(
              text: ' *',
              style: estilo == null ? TextStyle(color: t.accent) : TextStyle(color: EgresoEstilo.of(context).obligatorio, fontSize: 14),
            ),
        ],
      ),
      style: estilo ?? t.labelStyle(color),
    );
  }
}

/// Opción del control segmentado de fecha rápida ("Hoy", "Ayer").
/// Activa: rosa (formulario incompleto) o blanca con texto índigo (completo).
class _Segmento extends StatelessWidget {
  final String texto;
  final bool activo;
  final bool completo;
  final VoidCallback onTap;
  const _Segmento({required this.texto, required this.activo, required this.completo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = EgresoEstilo.of(context);
    final radio = BorderRadius.circular(8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: activo ? e.segmentoActivoFondo(completo) : Colors.transparent,
        borderRadius: radio,
        boxShadow: activo ? e.segmentoActivoSombra : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? e.segmentoActivoTexto(completo) : e.segmentoInactivoTexto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner "Escanear" al inicio del formulario: degradado rosa (incompleto) o índigo (completo),
/// ícono de cámara, "Escanear ticket" y botón blanco "Escanear". Todo el banner abre la captura.
class _EscanearBanner extends StatelessWidget {
  final bool completo;

  /// Se está verificando el servidor: el botón muestra una rueda en lugar del ícono.
  final bool verificando;
  final VoidCallback onTap;
  const _EscanearBanner({required this.completo, this.verificando = false, required this.onTap});

  /// Círculo blanco difuminado de fondo (decorativo).
  static Widget _mancha(double size, double sigma) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = EgresoEstilo.of(context);
    final radio = BorderRadius.circular(e.bannerRadio(completo));
    final colorBoton = e.bannerBotonTexto(completo);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(gradient: e.bannerDegradado(completo), borderRadius: radio, boxShadow: e.bannerSombra(completo)),
      child: ClipRRect(
        borderRadius: radio,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Stack(
              children: [
                Positioned(right: -24, bottom: -24, child: _mancha(112, 12)),
                Positioned(right: 48, top: 8, child: _mancha(64, 8)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: EgresoEstilo.bannerIcono,
                        height: EgresoEstilo.bannerIcono,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(e.bannerIconoRadio(completo)),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                        ),
                        child: const Icon(Icons.photo_camera_outlined, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          context.l10n.scanReceipt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.3, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón blanco (visual): el toque lo atiende todo el banner.
                      Container(
                        padding: completo
                            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (verificando) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colorBoton),
                              ),
                              const SizedBox(width: 8),
                            ] else if (!completo) ...[
                              Icon(Icons.qr_code_2_rounded, size: 16, color: colorBoton),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              context.l10n.scan2,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorBoton),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final e = EgresoEstilo.of(context);
    final radio = BorderRadius.circular(FormScreenTheme.radius);
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(color: e.agregarBorde, radius: FormScreenTheme.radius),
      child: Material(
        color: e.agregarFondo,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          splashColor: e.agregarToque,
          highlightColor: e.agregarToque.withValues(alpha: 0.5),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: e.agregarCirculo, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 14, color: e.agregarTexto),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.l10n.addLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.agregarTexto),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Total del gasto" (tema claro): oscura con punto ámbar mientras faltan obligatorios;
/// verde claro con el símbolo de la moneda en un recuadro verde al completarlos.
class _TotalGasto extends StatelessWidget {
  final bool completo;
  final String simbolo;
  final String total;
  final String renglones;
  const _TotalGasto({required this.completo, required this.simbolo, required this.total, required this.renglones});

  /// amber-400: punto del total incompleto.
  static const Color _amber400 = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final titulo = context.l10n.expenseTotal.toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: completo ? EgresoEstilo.totalVerdeDegradado : EgresoEstilo.totalOscuroDegradado),
        borderRadius: BorderRadius.circular(FormScreenTheme.radius),
        border: Border.all(color: completo ? EgresoEstilo.totalVerdeBorde : AppColors.slate800),
        boxShadow:
            completo ? const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1))] : EgresoEstilo.totalOscuroSombra,
      ),
      child: Row(
        children: [
          if (completo) ...[
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.emeraldDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1))],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(simbolo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: completo
                      ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.slate800)
                      : const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.slate400),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (!completo) ...[
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: _amber400, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        renglones,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: completo
                            ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.lightTextSecondary)
                            : const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate300),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                total,
                maxLines: 1,
                style: completo
                    ? const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: EgresoEstilo.emerald700)
                    : const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
              ),
            ),
          ),
        ],
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

/// Resultado de la lectura del ticket: verde si la suma coincide con el total impreso, ámbar si no. Se puede descartar.
class _TicketBanner extends StatelessWidget {
  final TicketParseResult result;
  final VoidCallback onClose;
  const _TicketBanner({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final difiere = result.tieneDiferenciaTotal;
    final color = difiere ? AppColors.amber : AppColors.emerald;
    final texto = difiere ? AppColors.amberDark : AppColors.emeraldDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: difiere ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(FormScreenTheme.radius),
        border: Border.all(color: color.withValues(alpha: difiere ? 0.5 : 0.4)),
      ),
      child: Row(
        children: [
          Icon(difiere ? Icons.warning_amber_rounded : Icons.receipt_long_rounded, color: difiere ? AppColors.amberDark : AppColors.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_ticketFeedback(result, context.l10n), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: texto)),
          ),
          IconButton(key: const ValueKey('ticket-descartar'), icon: const Icon(Icons.close, size: 18), onPressed: onClose),
        ],
      ),
    );
  }
}

/// Total del gasto en tema oscuro (la tarjeta de siempre).
class _TotalGastoOscuro extends StatelessWidget {
  final String simbolo;
  final String total;
  final String renglones;
  const _TotalGastoOscuro({required this.simbolo, required this.total, required this.renglones});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.accentSoft.withValues(alpha: 0.8), t.surface, t.accentSoft.withValues(alpha: 0.5)]),
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
                Text(context.l10n.expenseTotal.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: t.text)),
                Text(renglones, style: TextStyle(fontSize: 12, color: t.fieldLabel)),
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
                  Text(simbolo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.accent)),
                  const SizedBox(width: 3),
                  Text(total, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: t.accentStrong)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón inferior: rojo hasta completar los obligatorios, verde al completarlos; indicador mientras guarda.
class _BotonGuardar extends StatelessWidget {
  final bool completo;
  final bool guardando;
  final String texto;
  final VoidCallback onPressed;
  const _BotonGuardar({required this.completo, required this.guardando, required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final e = EgresoEstilo.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(FormScreenTheme.radius), boxShadow: e.botonSombra(completo)),
      child: ElevatedButton(
        key: const ValueKey('guardar-egreso'),
        onPressed: guardando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(FormScreenTheme.bottomButtonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FormScreenTheme.radius)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => e.botonFondo(completo: completo, presionado: states.contains(WidgetState.pressed)),
          ),
        ),
        child: guardando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Disquete hasta completar los obligatorios; check al completarlos.
                  Icon(completo ? Icons.check_rounded : Icons.save_rounded, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(texto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Fecha del egreso: control "Hoy" / "Ayer" (se destaca el que coincide) y selector de fecha.
class _FechaSeccion extends StatelessWidget {
  final DateTime fecha;
  final bool completo;
  final void Function(int diasAtras) onDiasAtras;
  final VoidCallback onElegir;
  const _FechaSeccion({required this.fecha, required this.completo, required this.onDiasAtras, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final t = FormScreenTheme.of(context);
    final e = EgresoEstilo.of(context);
    final ahora = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Etiqueta(context.l10n.date, color: t.fieldLabel, estilo: e.etiqueta)),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: e.segmentoFondo, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Segmento(texto: context.l10n.today, activo: DateUtils.isSameDay(fecha, ahora), completo: completo, onTap: () => onDiasAtras(0)),
                  const SizedBox(width: 6),
                  _Segmento(
                    texto: context.l10n.yesterday,
                    activo: DateUtils.isSameDay(fecha, ahora.subtract(const Duration(days: 1))),
                    completo: completo,
                    onTap: () => onDiasAtras(1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onElegir,
            borderRadius: BorderRadius.circular(FormScreenTheme.radius),
            child: EgresoFieldBox(
              stitch: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: EgresoEstilo.campoIcono,
                      height: EgresoEstilo.campoIcono,
                      decoration: BoxDecoration(color: e.campoIconoFondo(vacio: true), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.calendar_today_outlined, size: 15, color: e.campoIconoColor(vacio: true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(AppDateUtils.formatDate(fecha), style: e.fechaTexto)),
                    Icon(Icons.calendar_month_rounded, size: 18, color: e.fechaIconoDerecha),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Total del gasto (claro: oscuro incompleto / verde completo; en tema oscuro, la tarjeta de siempre) y el aviso
/// de fondos (saldo local, ya descuenta lo pendiente).
class _SeccionTotal extends StatelessWidget {
  final ExpenseFormState state;
  final Currency moneda;
  final String totalFormateado;
  const _SeccionTotal({required this.state, required this.moneda, required this.totalFormateado});

  @override
  Widget build(BuildContext context) {
    final renglones = context.l10n.linesCount(state.cantidadRenglones);
    final cuenta = state.cuentaSeleccionada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!EgresoEstilo.of(context).oscuro)
          _TotalGasto(completo: state.isFormComplete, simbolo: moneda.symbol, total: totalFormateado, renglones: renglones)
        else
          // El símbolo va aparte, más chico.
          _TotalGastoOscuro(simbolo: moneda.symbol, total: totalFormateado.replaceFirst('${moneda.symbol} ', ''), renglones: renglones),
        const SizedBox(height: 16),
        if (cuenta != null && state.fondosInsuficientes) FundsWarning(cuenta: cuenta, amountCents: state.totalCents),
      ],
    );
  }
}
