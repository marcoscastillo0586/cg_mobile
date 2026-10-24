import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../../../core/sync/outbox_repository.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/account_picker.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../providers/transfer_form_notifier.dart';
import '../providers/transfer_form_state.dart';
import '../../../../l10n/l10n.dart';

class CreateTransferScreen extends ConsumerStatefulWidget {
  /// Alta rechazada a corregir (desde "Pendientes y rechazados").
  final CorrectionSource? correction;
  const CreateTransferScreen({super.key, this.correction});

  @override
  ConsumerState<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends ConsumerState<CreateTransferScreen> {
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController();
  bool _montoInvalido = false;

  @override
  void initState() {
    super.initState();
    final c = widget.correction;
    if (c != null) {
      ref.read(transferFormNotifierProvider.notifier).prefill(c).then((_) {
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
    final estado = ref.read(transferFormNotifierProvider);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: estado.fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: context.l10n.transferDate,
    );

    if (seleccionada != null) {
      ref.read(transferFormNotifierProvider.notifier).setFecha(seleccionada);
    }
  }

  void _confirmarTransferencia() async {
    final notifier = ref.read(transferFormNotifierProvider.notifier);
    notifier.setConcepto(_conceptoController.text.trim());

    final ok = await notifier.realizarTransferencia();
    if (!mounted) return;
    if (ok) {
      await afterLocalWrite(context, ref, context.l10n.transfer);
      if (mounted) context.pop();
    } else {
      final error = ref.read(transferFormNotifierProvider).error;
      if (error != null) AppFeedback.showError(context, describeWithCode(error, context.l10n));
    }
  }

  static String _etiqueta(LocalAccount c) =>
      '${c.name.toUpperCase()} (${Money.format(c.balanceCents, currency: c.currency)})';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferFormNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatoFecha = DateFormat('dd/MM/yyyy').format(state.fecha);
    if (state.status == TransferFormStatus.error) {
      return LocalDataError(error: state.error!, onRetry: ref.read(transferFormNotifierProvider.notifier).cargarCuentas);
    }
    final origen = state.origen;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.correction != null ? (context.l10n.correctTransfer) : (context.l10n.transferMoney)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Card de Cuentas (Origen -> Destino con botón de intercambio)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Cuenta Origen
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.rose, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.source,
                                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: state.selectedOrigenId,
                                  hint: Text(context.l10n.selectSource),
                                  items: state.cuentas.map((lug) {
                                    return DropdownMenuItem<int>(
                                      value: lug.localId,
                                      child: Text(
                                        _etiqueta(lug),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      AppFeedback.selection();
                                      ref.read(transferFormNotifierProvider.notifier).setOrigen(val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Botón de Intercambio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(child: Divider()),
                        IconButton(
                          icon: const Icon(Icons.swap_vert_rounded, color: AppColors.primary),
                          tooltip: context.l10n.swapAccounts,
                          onPressed: () {
                            AppFeedback.medium();
                            ref.read(transferFormNotifierProvider.notifier).intercambiarCuentas();
                          },
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    // Cuenta Destino
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: AppColors.emerald, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.destination,
                                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: state.selectedDestinoId,
                                  hint: Text(origen != null && state.destinosValidos.isEmpty
                                      ? (context.l10n.noOtherAccount(origen.currency.code))
                                      : (context.l10n.selectDestination)),
                                  items: state.destinosValidos.map((lug) {
                                    return DropdownMenuItem<int>(
                                      value: lug.localId,
                                      child: Text(
                                        _etiqueta(lug),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(transferFormNotifierProvider.notifier).setDestino(val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Monto a Transferir
            Text(
              context.l10n.amountTransfer,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final cents = Money.parseInput(v);
                setState(() => _montoInvalido = v.trim().isNotEmpty && cents == null);
                ref.read(transferFormNotifierProvider.notifier).setMonto(cents ?? 0);
              },
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
              decoration: InputDecoration(
                prefixText: '${origen?.currency.symbol ?? r'$'} ',
                prefixStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
                hintText: '0,00',
                errorText: _montoInvalido ? (context.l10n.invalidAmountMax2Decimals) : null,
              ),
            ),
            const SizedBox(height: 18),

            // 3. Concepto / Motivo (Punto 9.2: Máximo 20 caracteres alfanuméricos)
            Text(
              context.l10n.conceptReference,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _conceptoController,
              maxLength: 20,
              inputFormatters: [
                LengthLimitingTextInputFormatter(20),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9áéíóúÁÉÍÓÚñÑ\s]')),
              ],
              decoration: InputDecoration(
                hintText: context.l10n.eGWithdrawal,
                prefixIcon: const Icon(Icons.swap_horiz_rounded, size: 20),
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),

            // 4. Fecha
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

            // Aviso de fondos antes de guardar (saldo local del origen).
            if (origen != null && state.fondosInsuficientes)
              FundsWarning(cuenta: origen, amountCents: state.montoCents, blocking: true),

            // 5. Botón Confirmar
            ElevatedButton(
              key: const ValueKey('guardar-transferencia'),
              onPressed: state.isSubmitting || state.fondosInsuficientes ? null : _confirmarTransferencia,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                  : Text(context.l10n.confirmTransfer),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
