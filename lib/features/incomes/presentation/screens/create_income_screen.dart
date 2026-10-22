import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_picker.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/income_form_notifier.dart';
import '../providers/income_form_state.dart';
import '../../../movements/data/local_movement_writer.dart' show conceptMax;

class CreateIncomeScreen extends ConsumerStatefulWidget {
  const CreateIncomeScreen({super.key});

  @override
  ConsumerState<CreateIncomeScreen> createState() => _CreateIncomeScreenState();
}

class _CreateIncomeScreenState extends ConsumerState<CreateIncomeScreen> {
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController();
  bool _montoInvalido = false;

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
      helpText: 'Fecha del ingreso',
    );

    if (seleccionada != null) {
      AppFeedback.selection();
      ref.read(incomeFormNotifierProvider.notifier).setFecha(seleccionada);
    }
  }

  void _guardarIngreso() async {
    final isEn = ref.read(settingsProvider).language == 'en';
    final notifier = ref.read(incomeFormNotifierProvider.notifier);
    notifier.setMonto(Money.parseInput(_montoController.text) ?? 0);
    notifier.setConcepto(_conceptoController.text.trim());

    final ok = await notifier.guardarIngreso();
    if (!mounted) return;
    if (ok) {
      await afterLocalWrite(context, ref, isEn ? 'Income' : 'Ingreso', isEn: isEn);
      if (mounted) context.pop();
    } else {
      final error = ref.read(incomeFormNotifierProvider).error;
      if (error != null) AppFeedback.showError(context, describeWithCode(error, isEn: isEn));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomeFormNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatoFecha = DateFormat('dd/MM/yyyy').format(state.fecha);

    final isEn = settings.language == 'en';
    if (state.status == IncomeFormStatus.error) {
      return LocalDataError(error: state.error!, isEn: isEn, onRetry: ref.read(incomeFormNotifierProvider.notifier).cargarCuentas);
    }
    final tituloModulo = isEn ? 'New Income' : 'Nuevo Ingreso';
    final labelCuenta = settings.language == 'en' ? 'Destination account.' : 'Cuenta de destino.';

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloModulo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
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
              isEn: isEn,
              onSelect: (id) => ref.read(incomeFormNotifierProvider.notifier).setCuenta(id),
            ),
            const SizedBox(height: 20),

            // 2. Monto
            const Text(
              'Monto a Ingresar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                errorText: _montoInvalido ? (isEn ? 'Invalid amount (max. 2 decimals)' : 'Importe inválido (máx. 2 decimales)') : null,
              ),
            ),
            const SizedBox(height: 18),

            // 3. Concepto
            const Text(
              'Concepto / Motivo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _conceptoController,
              maxLength: conceptMax,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'Ej: Sueldo, Cobro freelance, Venta... (vacío: "$conceptoIngresoPorDefecto")',
                prefixIcon: Icon(Icons.arrow_downward_rounded, size: 20, color: AppColors.emerald),
              ),
            ),
            const SizedBox(height: 18),

            // 4. Selector de Fecha
            const Text(
              'Fecha',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  : const Text('Registrar Ingreso'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
