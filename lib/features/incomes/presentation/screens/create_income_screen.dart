import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/income_form_notifier.dart';

class CreateIncomeScreen extends ConsumerStatefulWidget {
  const CreateIncomeScreen({super.key});

  @override
  ConsumerState<CreateIncomeScreen> createState() => _CreateIncomeScreenState();
}

class _CreateIncomeScreenState extends ConsumerState<CreateIncomeScreen> {
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController();

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
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    ref.read(incomeFormNotifierProvider.notifier).setMonto(monto);
    ref.read(incomeFormNotifierProvider.notifier).setConcepto(_conceptoController.text.trim());

    final ok = await ref.read(incomeFormNotifierProvider.notifier).guardarIngreso();

    if (ok && mounted) {
      await ref.read(dashboardNotifierProvider.notifier).cargarDashboard();

      if (mounted) {
        AppFeedback.showSuccess(context, '¡Ingreso registrado con éxito!');
        context.pop();
      }
    } else if (mounted) {
      final error = ref.read(incomeFormNotifierProvider).errorMessage ?? 'Error al guardar';
      AppFeedback.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomeFormNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatoFecha = DateFormat('dd/MM/yyyy').format(state.fecha);

    final tituloModulo = settings.language == 'en' ? 'New Income' : 'Nuevo Ingreso';
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
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.lugares.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final lug = state.lugares[index];
                  final isSelected = lug.idLugar == state.selectedLugarId;
                  return ChoiceChip(
                    label: Text(lug.nombre.toUpperCase()),
                    selected: isSelected,
                    selectedColor: AppColors.emerald.withValues(alpha: 0.2),
                    onSelected: (_) {
                      AppFeedback.selection();
                      ref.read(incomeFormNotifierProvider.notifier).setLugar(lug.idLugar);
                    },
                  );
                },
              ),
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
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.emerald),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.emerald),
                hintText: '0,00',
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
              decoration: const InputDecoration(
                hintText: 'Ej: Sueldo, Cobro freelance, Venta...',
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
