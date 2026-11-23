import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_controller.dart';
import 'package:go_router/go_router.dart';
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
import '../../../../core/widgets/bottom_safe_area.dart';
import '../../../../core/widgets/date_field_tile.dart';
import '../../../../core/widgets/submit_button.dart';

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
    // Se muestra enseguida con lo guardado; con conexión se actualiza al llegar lo del servidor. Después del
    // primer cuadro: cambiar un provider mientras se arma la pantalla no está permitido.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await ref.read(transferFormNotifierProvider.notifier).recargarCuentas();
    });
    final c = widget.correction;
    if (c != null) {
      Future.microtask(() => ref.read(transferFormNotifierProvider.notifier).prefill(c)).then((_) {
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

  /// Evita un segundo guardado mientras se espera la respuesta del servidor.
  bool _guardando = false;

  void _confirmarTransferencia() async {
    if (_guardando) return;
    _guardando = true;
    try {
      await _confirmarTransferenciaAhora();
    } finally {
      _guardando = false;
    }
  }

  Future<void> _confirmarTransferenciaAhora() async {
    final notifier = ref.read(transferFormNotifierProvider.notifier);
    notifier.setConcepto(_conceptoController.text.trim());

    final ok = await notifier.realizarTransferencia();
    if (!mounted) return;
    if (ok) {
      if (await afterLocalWrite(context, ref, context.l10n.transfer) && mounted) context.pop();
    } else {
      final error = ref.read(transferFormNotifierProvider).error;
      if (error != null) AppFeedback.showError(context, describeWithCode(error, context.l10n));
    }
  }

  /// Sin otra cuenta de la moneda del origen se avisa en vez de pedir que se elija.
  static String _hintDestino(TransferFormState state, AppLocalizations l) {
    final origen = state.origen;
    return origen != null && state.destinosValidos.isEmpty ? l.noOtherAccount(origen.currency.code) : l.selectDestination;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferFormNotifierProvider);
    if (state.status == TransferFormStatus.error) {
      return LocalDataError(error: state.error!, onRetry: ref.read(transferFormNotifierProvider.notifier).cargarCuentas);
    }
    final origen = state.origen;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.correction != null ? (context.l10n.correctTransfer) : (context.l10n.transferMoney)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0).withBottomSafeArea(context),
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
                    _CuentaFila(
                      icono: Icons.arrow_upward_rounded,
                      color: AppColors.rose,
                      titulo: context.l10n.source,
                      hint: context.l10n.selectSource,
                      value: state.selectedOrigenId,
                      cuentas: state.cuentas,
                      onChanged: (val) {
                        AppFeedback.selection();
                        ref.read(transferFormNotifierProvider.notifier).setOrigen(val);
                      },
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

                    // Cuenta Destino (sólo de la moneda del origen)
                    _CuentaFila(
                      icono: Icons.arrow_downward_rounded,
                      color: AppColors.emerald,
                      titulo: context.l10n.destination,
                      hint: _hintDestino(state, context.l10n),
                      value: state.selectedDestinoId,
                      cuentas: state.destinosValidos,
                      onChanged: (val) => ref.read(transferFormNotifierProvider.notifier).setDestino(val),
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
            DateFieldTile(fecha: state.fecha, onTap: () => _seleccionarFecha(context)),
            const SizedBox(height: 32),

            // Aviso de fondos antes de guardar (saldo local del origen).
            if (origen != null && state.fondosInsuficientes)
              FundsWarning(cuenta: origen, amountCents: state.montoCents, blocking: true),

            // 5. Botón Confirmar
            SubmitButton(
              key: const ValueKey('guardar-transferencia'),
              label: context.l10n.confirmTransfer,
              loading: state.isSubmitting,
              color: AppColors.primary,
              onPressed: _confirmarTransferencia,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Origen o destino: ícono, título y la lista de cuentas con su saldo.
class _CuentaFila extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String hint;
  final int? value;
  final List<LocalAccount> cuentas;
  final ValueChanged<int> onChanged;
  const _CuentaFila({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.hint,
    required this.value,
    required this.cuentas,
    required this.onChanged,
  });

  static String _etiqueta(LocalAccount c) => '${c.name.toUpperCase()} (${Money.format(c.balanceCents, currency: c.currency)})';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icono, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: value,
                  hint: Text(hint),
                  items: [
                    for (final c in cuentas)
                      DropdownMenuItem<int>(
                        value: c.localId,
                        child: Text(_etiqueta(c), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) onChanged(val);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
