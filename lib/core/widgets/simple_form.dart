import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../money/money.dart';
import '../sync/outbox_repository.dart';
import '../sync/sync_controller.dart';
import '../utils/app_feedback.dart';
import '../../l10n/l10n.dart';
import 'date_field_tile.dart';

/// Lo que las pantallas de ingreso y transferencia usan de su formulario.
abstract interface class SimpleFormActions {
  /// Tras traer lo del servidor: actualiza cuentas (saldos) sin tocar lo cargado.
  Future<void> recargarCuentas();

  /// Precarga un alta rechazada para corregirla.
  Future<void> prefill(CorrectionSource c);

  void setFecha(DateTime fecha);
}

/// Monto, concepto y fecha de un formulario simple (ingreso o transferencia): al abrir trae lo del servidor (si hay
/// conexión) y, si es una corrección, precarga lo rechazado.
mixin SimpleFormScreen<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final montoController = TextEditingController();
  final conceptoController = TextEditingController();

  SimpleFormActions get formActions;
  CorrectionSource? get correction;

  @override
  void initState() {
    super.initState();
    // Se muestra enseguida con lo guardado; con conexión se actualiza al llegar lo del servidor. Después del
    // primer cuadro: cambiar un provider mientras se arma la pantalla no está permitido.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await formActions.recargarCuentas();
    });
    final c = correction;
    if (c == null) return;
    Future.microtask(() => formActions.prefill(c)).then((_) {
      if (!mounted) return;
      montoController.text = Money.toApiDecimal(c.amountCents).replaceAll('.', ',');
      conceptoController.text = c.concept;
    });
  }

  @override
  void dispose() {
    montoController.dispose();
    conceptoController.dispose();
    super.dispose();
  }

  /// Selector de fecha (hasta 30 días adelante).
  Future<void> seleccionarFecha(DateTime actual, String helpText) async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: helpText,
    );
    if (seleccionada == null) return;
    AppFeedback.selection();
    formActions.setFecha(seleccionada);
  }
}

/// "Fecha" con su campo, como sección de un formulario.
class DateFieldSection extends StatelessWidget {
  final DateTime fecha;
  final VoidCallback onTap;
  const DateFieldSection({super.key, required this.fecha, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          DateFieldTile(fecha: fecha, onTap: onTap),
        ],
      );
}
