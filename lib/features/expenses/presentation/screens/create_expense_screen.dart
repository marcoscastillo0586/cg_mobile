import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/account_picker.dart';
import '../../../../routes/app_routes.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../providers/expense_form_notifier.dart';
import '../providers/expense_form_state.dart';
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

  @override
  void initState() {
    super.initState();
    _conceptoGeneralController.addListener(() {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .setConceptoGeneral(_conceptoGeneralController.text);
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
    super.dispose();
  }

  void _seleccionarFecha(BuildContext context) async {
    final estado = ref.read(expenseFormNotifierProvider);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: estado.fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Fecha del egreso',
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

  void _guardarGasto() async {
    final st = ref.read(expenseFormNotifierProvider);
    final cuenta = st.cuentaSeleccionada;
    // Sin fondos se puede guardar igual (el dinero puede no estar cargado), pero se avisa y se confirma.
    if (cuenta != null && st.fondosInsuficientes) {
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
    final ok = await ref.read(expenseFormNotifierProvider.notifier).guardarEgreso();
    if (!mounted) return;
    if (ok && esQr) {
      // Quedó registrado en el servidor: se descarga en la sincronización.
      unawaited(ref.read(syncControllerProvider.notifier).sync());
      AppFeedback.showSuccess(context, context.l10n.ticketRecordedServer);
      context.pop(true);
    } else if (ok) {
      await afterLocalWrite(context, ref, context.l10n.expense);
      if (mounted) context.pop(true);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final totalFormateado = Money.format(state.totalCents, currency: cuenta?.currency ?? Currency.ars);

    final tituloModulo = widget.correction != null
        ? (context.l10n.correctExpense)
        : (context.l10n.newExpense);
    final textoBoton = (context.l10n.registerExpense(totalFormateado));

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloModulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: context.l10n.scanReceipt,
            onPressed: () => _abrirCapturaTicket(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Selector de Cuenta Origen
                  const Text(
                    'Cuenta de Origen',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  AccountPicker(
                    cuentas: state.cuentas,
                    selectedId: state.selectedCuentaId,
                    onSelect: (id) => ref.read(expenseFormNotifierProvider.notifier).setCuenta(id),
                  ),
                  const SizedBox(height: 18),

                  // 2. Encabezado: Concepto General y Fecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Concepto General (Obligatorio)
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Concepto General *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _conceptoGeneralController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Ej: Supermercado, Librería...',
                                prefixIcon: Icon(Icons.storefront_rounded, size: 20),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Selector de Fecha (dd/MM/yyyy)
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _seleccionarFecha(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatoFecha,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      size: 18,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Banner Feedback de Lectura de Ticket
                  if (state.qrFeedback != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (state.ticketParseResult?.tieneDiferenciaTotal == true)
                            ? AppColors.amber.withValues(alpha: 0.15)
                            : AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
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
                              state.qrFeedback!,
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

                  // 4. Título Renglones (sin botón redundante al costado)
                  const Text(
                    'Renglones',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),

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

                  const SizedBox(height: 8),

                  // Botón principal único para agregar renglón al pie de la lista
                  OutlinedButton.icon(
                    onPressed: () {
                      AppFeedback.light();
                      ref.read(expenseFormNotifierProvider.notifier).agregarRenglon();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Agregar Renglón',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Banner Resumen ("Total de gastos")
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.rose.withValues(alpha: 0.25),
                                AppColors.primary.withValues(alpha: 0.15),
                              ]
                            : [
                                AppColors.rose.withValues(alpha: 0.10),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.rose.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.savings_outlined,
                                color: AppColors.rose,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total del Gasto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                                Text(
                                  '${state.cantidadRenglones} ${state.cantidadRenglones == 1 ? "renglón" : "renglones"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          totalFormateado,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Aviso de fondos antes de guardar (saldo local, ya descuenta lo pendiente).
                  if (cuenta != null && state.fondosInsuficientes)
                    FundsWarning(cuenta: cuenta, amountCents: state.totalCents),

                  // 5. Botón Final
                  ElevatedButton(
                    key: const ValueKey('guardar-egreso'),
                    onPressed: state.isSubmitting ? null : _guardarGasto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isFormComplete ? AppColors.primary : AppColors.rose,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                              const Icon(Icons.save_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                textoBoton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }
}
