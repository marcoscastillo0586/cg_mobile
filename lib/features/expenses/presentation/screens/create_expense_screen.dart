import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../routes/app_routes.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../../dashboard/presentation/providers/novedades_notifier.dart';
import '../../../movements/data/repositories/movement_repository_impl.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/ticket_parse_result.dart';
import '../providers/expense_form_notifier.dart';
import '../widgets/expense_account_selector.dart';
import '../widgets/renglon_gasto_card.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  ConsumerState<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _conceptoGeneralController = TextEditingController();
  bool _initializedController = false;

  @override
  void initState() {
    super.initState();
    _conceptoGeneralController.addListener(() {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .setConceptoGeneral(_conceptoGeneralController.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editIdStr = GoRouterState.of(context).uri.queryParameters['edit_id'];
      if (editIdStr != null && int.tryParse(editIdStr) != null) {
        final editId = int.parse(editIdStr);
        final movementRepository = ref.read(movementRepositoryProvider);
        ref
            .read(expenseFormNotifierProvider.notifier)
            .cargarGastoParaEditar(editId, movementRepository)
            .then((_) {
          if (mounted) {
            final state = ref.read(expenseFormNotifierProvider);
            _conceptoGeneralController.text = state.conceptoGeneral;
            _initializedController = true;
          }
        });
      }
    });
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
    }
  }

  void _guardarGasto() async {
    if (_conceptoGeneralController.text.trim().isEmpty) {
      AppFeedback.showError(context, 'El Concepto General es obligatorio');
      return;
    }

    final ok = await ref.read(expenseFormNotifierProvider.notifier).guardarEgreso();

    if (ok && mounted) {
      await ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
      unawaited(ref.read(novedadesNotifierProvider.notifier).calcularNovedades());

      if (mounted) {
        final mensajeStr = ref.read(expenseFormNotifierProvider).isEditing
            ? '¡Egreso actualizado correctamente!'
            : '¡Egreso registrado correctamente!';
        AppFeedback.showSuccess(context, mensajeStr);
        context.pop(true);
      }
    } else if (mounted) {
      final error = ref.read(expenseFormNotifierProvider).errorMessage ??
          'Ocurrió un error al guardar el gasto';
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseFormNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isEditing && !_initializedController) {
      _conceptoGeneralController.text = state.conceptoGeneral;
      _initializedController = true;
    }

    final lugares = state.formData?.lugares ?? [];
    final categorias = state.formData?.categorias ?? [];
    final sugerenciasConceptos = state.formData?.conceptos ?? [];
    final formatoFecha = AppDateUtils.formatDate(state.fecha);

    final totalFormateado = AppCurrencyUtils.format(
      state.totalCalculado,
      symbol: '\$',
    );

    // Título y texto de botón según idioma e inicio de edición
    final isEn = settings.language == 'en';
    final tituloModulo = state.isEditing
        ? (isEn ? 'Edit Expense' : 'Editar egreso')
        : (isEn ? 'New Expense' : 'Nuevo Egreso');
    final textoBoton = state.isEditing
        ? (isEn ? 'Save changes' : 'Guardar cambios')
        : (isEn ? 'Register Expense ($totalFormateado)' : 'Registrar Gasto ($totalFormateado)');

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloModulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: isEn ? 'Scan receipt' : 'Escanear ticket',
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
                  ExpenseAccountSelector(
                    cuentas: lugares,
                    selectedId: state.selectedLugarId,
                    onSelect: (idLugar) {
                      ref.read(expenseFormNotifierProvider.notifier).setLugar(idLugar);
                    },
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

                  // 5. Botón Final
                  ElevatedButton(
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
