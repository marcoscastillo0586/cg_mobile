import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_picker.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../providers/income_form_notifier.dart';
import '../providers/income_form_state.dart';
import '../../../movements/data/local_movement_writer.dart' show conceptMax;
import '../../../../l10n/l10n.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

class CreateIncomeScreen extends ConsumerStatefulWidget {
  /// Alta rechazada a corregir (desde "Pendientes y rechazados").
  final CorrectionSource? correction;
  const CreateIncomeScreen({super.key, this.correction});

  @override
  ConsumerState<CreateIncomeScreen> createState() => _CreateIncomeScreenState();
}

class _CreateIncomeScreenState extends ConsumerState<CreateIncomeScreen> {
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController();
  bool _montoInvalido = false;

  @override
  void initState() {
    super.initState();
    // Se muestra enseguida con lo guardado; con conexión se actualiza al llegar lo del servidor.
    ref.read(syncControllerProvider.notifier).refreshIfOnline().then((_) {
      if (mounted) ref.read(incomeFormNotifierProvider.notifier).recargarCuentas();
    });
    final c = widget.correction;
    if (c != null) {
      ref.read(incomeFormNotifierProvider.notifier).prefill(c).then((_) {
        if (!mounted) return;
        _montoController.text = Money.toApiDecimal(c.amountCents).replaceAll('.', ',');
        _conceptoController.text = c.concept;
      });
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _conceptoController.dispose();
    super.dispose();
  }

  void _seleccionarFecha(BuildContext context) async {
    final estado = ref.read(incomeFormNotifierProvider);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: estado.fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: context.l10n.incomeDate,
    );

    if (seleccionada != null) {
      AppFeedback.selection();
      ref.read(incomeFormNotifierProvider.notifier).setFecha(seleccionada);
    }
  }

  /// Evita un segundo guardado mientras se espera la respuesta del servidor.
  bool _guardando = false;

  void _guardarIngreso() async {
    if (_guardando) return;
    _guardando = true;
    try {
      await _guardarIngresoAhora();
    } finally {
      _guardando = false;
    }
  }

  Future<void> _guardarIngresoAhora() async {
    final notifier = ref.read(incomeFormNotifierProvider.notifier);
    notifier.setMonto(Money.parseInput(_montoController.text) ?? 0);
    notifier.setConcepto(_conceptoController.text.trim());

    final ok = await notifier.guardarIngreso();
    if (!mounted) return;
    if (ok) {
      if (await afterLocalWrite(context, ref, context.l10n.income) && mounted) context.pop();
    } else {
      final error = ref.read(incomeFormNotifierProvider).error;
      if (error != null) AppFeedback.showError(context, describeWithCode(error, context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomeFormNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatoFecha = DateFormat('dd/MM/yyyy').format(state.fecha);

    if (state.status == IncomeFormStatus.error) {
      return LocalDataError(error: state.error!, onRetry: ref.read(incomeFormNotifierProvider.notifier).cargarCuentas);
    }
    final tituloModulo = widget.correction != null
        ? (context.l10n.correctIncome)
        : (context.l10n.newIncome);
    final labelCuenta = context.l10n.destinationAccount;

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloModulo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0).withBottomSafeArea(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cuenta de Destino (Punto 8.1 y 8.2)
            Text(
              labelCuenta,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            AccountPicker(
              cuentas: state.cuentas,
              selectedId: state.selectedCuentaId,
              onSelect: (id) => ref.read(incomeFormNotifierProvider.notifier).setCuenta(id),
            ),
            const SizedBox(height: 20),

            // 2. Monto
            Text(
              context.l10n.amountAdd,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => _montoInvalido = v.trim().isNotEmpty && Money.parseInput(v) == null),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.emerald),
              decoration: InputDecoration(
                prefixText: '${state.cuentaSeleccionada?.currency.symbol ?? r'$'} ',
                prefixStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.emerald),
                hintText: '0,00',
                errorText: _montoInvalido ? (context.l10n.invalidAmountMax2Decimals) : null,
              ),
            ),
            const SizedBox(height: 18),

            // 3. Concepto
            Text(
              context.l10n.conceptReason,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _conceptoController,
              maxLength: conceptMax,
              decoration: InputDecoration(
                counterText: '',
                hintText: context.l10n.eGSalaryFreelancePayment(conceptoIngresoPorDefecto),
                prefixIcon: const Icon(Icons.arrow_downward_rounded, size: 20, color: AppColors.emerald),
              ),
            ),
            const SizedBox(height: 18),

            // 4. Selector de Fecha
            Text(
              context.l10n.date,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _seleccionarFecha(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(formatoFecha, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 5. Botón Guardar
            ElevatedButton(
              key: const ValueKey('guardar-ingreso'),
              onPressed: state.isSubmitting ? null : _guardarIngreso,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(context.l10n.recordIncome2),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
