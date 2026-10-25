import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../../../core/network/server_reachability.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../data/local_movement_editor.dart';
import '../../data/local_movement_writer.dart' show conceptMax;
import '../local_write_feedback.dart';
import '../../../../l10n/l10n.dart';

/// Edición de un comprobante desde la base local (funciona sin conexión): encabezado, cada
/// renglón (editar y borrar), transferencia como par y borrado del comprobante. Todo pasa por
/// la outbox; el envío lo hace el sincronizador.
class MovementEditScreen extends ConsumerStatefulWidget {
  final int serverId;

  /// Abre directamente la confirmación de borrado (botón "Eliminar" de la lista).
  final bool askDelete;
  const MovementEditScreen({super.key, required this.serverId, this.askDelete = false});

  @override
  ConsumerState<MovementEditScreen> createState() => _MovementEditScreenState();
}

class _MovementEditScreenState extends ConsumerState<MovementEditScreen> {
  EditableMovement? _m;
  List<LocalAccount> _cuentas = const [];
  List<LocalCategory> _categorias = const [];
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  // Encabezado
  final _concepto = TextEditingController();
  DateTime? _fecha;
  int? _cuenta;

  // Transferencia
  int? _origen, _destino;
  final _montoTransfer = TextEditingController();


  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.askDelete && mounted && _m != null) _deleteMovement();
    });
  }

  @override
  void dispose() {
    _concepto.dispose();
    _montoTransfer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final editor = await ref.read(localMovementEditorProvider);
      final catalog = await ref.read(localCatalogProvider);
      // Id negativo: comprobante que todavía no llegó al servidor (historial sin conexión).
      final m = widget.serverId < 0 ? await editor.load(-widget.serverId) : await editor.loadByServerId(widget.serverId);
      final cuentas = await catalog.activeAccounts();
      final categorias = await catalog.expenseCategories();
      if (!mounted) return;
      setState(() {
        _m = m;
        _cuentas = cuentas;
        _categorias = categorias;
        _error = null;
        _loading = false;
        if (m != null) {
          _concepto.text = m.generalConcept ?? '';
          _fecha = DateTime.tryParse(m.occurredAt.substring(0, 10));
          _cuenta = m.isTransfer || m.details.isEmpty ? null : m.details.first.accountLocalId;
          _origen = m.transferFrom?.accountLocalId;
          _destino = m.transferTo?.accountLocalId;
          final amount = m.transferTo?.amountCents;
          _montoTransfer.text = amount == null ? '' : Money.toApiDecimal(amount).replaceAll('.', ',');
        }
      });
    } catch (e) {
      debugPrint('[EDITAR] No se pudo leer la base local: $e');
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  LocalAccount? _account(int? id) => _cuentas.where((c) => c.localId == id).firstOrNull;

  /// Aviso de saldo negativo antes de guardar (egresos/ingresos: se puede guardar igual).
  Future<bool> _confirmNegative(Map<int, int> deltas) async {
    // Sin conexión se guarda sin diálogos (el servidor decide al sincronizar).
    if (ServerReachability.offline.value) return true;
    final negativas = <String>[];
    for (final e in deltas.entries) {
      final a = _account(e.key);
      if (a == null || e.value >= 0) continue;
      final queda = a.balanceCents + e.value;
      if (queda < 0) negativas.add('${a.name.toUpperCase()} ${context.l10n.will} ${Money.format(queda, currency: a.currency)}');
    }
    if (negativas.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.balanceWillNegative),
        content: Text('${negativas.join('\n')}.\n${context.l10n.recordIncomeThatAccount}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(key: const ValueKey('guardar-igual'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.saveAnyway)),
        ],
      ),
    );
    return ok == true;
  }

  /// Ejecuta una edición local, avisa y envía si hay red; los errores se muestran traducidos.
  Future<void> _run(Future<Object?> Function(LocalMovementEditor e) action, {bool close = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(await ref.read(localMovementEditorProvider));
      // Se envía ya; si el servidor lo rechaza, el cambio no queda guardado.
      final rejection = await ref.read(syncControllerProvider.notifier).sendNow();
      if (!mounted) return;
      if (rejection != null) {
        AppFeedback.showError(context, describeWithCode(rejection, context.l10n));
        await _load();
        return;
      }
      AppFeedback.showSuccess(context, context.l10n.changesSaved);
      if (close) {
        context.pop(true);
      } else {
        await _load();
      }
    } catch (e) {
      debugPrint('[EDITAR] No se guardó: $e');
      if (mounted) AppFeedback.showError(context, describeWithCode(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveHeader() async {
    final m = _m!;
    final cambiaCuenta = !m.isTransfer && _cuenta != null && m.details.any((d) => d.accountLocalId != _cuenta);
    if (cambiaCuenta) {
      final sum = m.details.fold<int>(0, (s, d) => s + d.amountCents);
      final deltas = <int, int>{_cuenta!: sum};
      for (final d in m.details) {
        deltas[d.accountLocalId] = (deltas[d.accountLocalId] ?? 0) - d.amountCents;
      }
      if (!await _confirmNegative(deltas)) return;
    }
    await _run((e) => e.updateHeader(m.localId, generalConcept: _concepto.text, date: _fecha, accountLocalId: cambiaCuenta ? _cuenta : null));
  }

  Future<void> _saveDetail(EditableDetail d, {required String concept, required int? category, required int? amount}) async {
    final m = _m!;
    if (amount == null) {
      AppFeedback.showError(context, context.l10n.invalidAmountMax2Decimals);
      return;
    }
    final signed = m.type == 2 ? -amount : amount;
    if (!await _confirmNegative({d.accountLocalId: signed - d.amountCents})) return;
    await _run((e) => e.updateDetail(d.localId, concept: concept, categoryLocalId: category, amountCents: amount));
  }

  Future<void> _deleteDetail(EditableDetail d) async {
    if (!await _confirmNegative({d.accountLocalId: -d.amountCents})) return;
    await _run((e) => e.deleteDetail(d.localId));
  }

  Future<void> _saveTransfer() async {
    final m = _m!;
    final amount = Money.parseInput(_montoTransfer.text);
    if (_origen == null || _destino == null || amount == null) {
      AppFeedback.showError(context, context.l10n.completeSourceDestinationValidAmount);
      return;
    }
    await _run((e) => e.updateTransfer(m.localId, fromLocalId: _origen!, toLocalId: _destino!, amountCents: amount));
  }

  Future<void> _deleteMovement() async {
    final m = _m!;
    final deltas = <int, int>{};
    for (final d in m.details) {
      deltas[d.accountLocalId] = (deltas[d.accountLocalId] ?? 0) - d.amountCents;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteMovement),
        content: Text(context.l10n.removedAllItsLines),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(key: const ValueKey('confirmar-eliminar'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !await _confirmNegative(deltas)) return;
    await _run((e) => e.deleteMovement(m.localId), close: true);
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editMovement)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(describeWithCode(_error!, context.l10n))))
              : m == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(context.l10n.movementNotPhoneWasDeleted),
                      ),
                    )
                  : AbsorbPointer(
                      absorbing: _busy,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _headerCard(m),
                          const SizedBox(height: 12),
                          if (m.isTransfer) _transferCard(m) else ..._detailCards(m),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            key: const ValueKey('eliminar-comprobante'),
                            onPressed: _deleteMovement,
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                            label: Text(context.l10n.deleteMovement2, style: const TextStyle(color: AppColors.rose)),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _headerCard(EditableMovement m) {
    final currencies = m.details.map((d) => d.currency).toSet();
    final opciones = _cuentas.where((c) => currencies.isEmpty || currencies.contains(c.currency)).toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.header, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              key: const ValueKey('editar-concepto'),
              controller: _concepto,
              maxLength: conceptMax,
              decoration: InputDecoration(labelText: context.l10n.generalConcept, counterText: ''),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('editar-fecha'),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(_fecha == null ? '—' : DateFormat('dd/MM/yyyy').format(_fecha!)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fecha ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _fecha = picked);
              },
            ),
            if (!m.isTransfer && opciones.any((c) => c.localId == _cuenta)) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const ValueKey('editar-cuenta'),
                initialValue: _cuenta,
                decoration: InputDecoration(labelText: context.l10n.accountAllLines),
                items: [
                  for (final c in opciones)
                    DropdownMenuItem(value: c.localId, child: Text('${c.name.toUpperCase()} (${Money.format(c.balanceCents, currency: c.currency)})')),
                ],
                onChanged: (v) => setState(() => _cuenta = v),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton(
              key: const ValueKey('guardar-encabezado'),
              onPressed: _saveHeader,
              child: Text(context.l10n.saveHeader),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailCards(EditableMovement m) => [
        Text('${context.l10n.lines2} (${m.details.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (!m.synced)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              context.l10n.notServerYetLinesCan,
              style: const TextStyle(fontSize: 12, color: AppColors.amberDark),
            ),
          ),
        for (final d in m.details)
          _DetailEditor(
            key: ValueKey('renglon-${d.localId}'),
            detail: d,
            isIncome: m.type == 1,
            enabled: m.synced,
            categorias: _categorias,
            onSave: (concept, category, amount) => _saveDetail(d, concept: concept, category: category, amount: amount),
            onDelete: () => _deleteDetail(d),
          ),
      ];

  Widget _transferCard(EditableMovement m) {
    final origen = _account(_origen);
    final destinos = _cuentas.where((c) => c.localId != _origen && (origen == null || c.currency == origen.currency)).toList();
    String label(LocalAccount c) => '${c.name.toUpperCase()} (${Money.format(c.balanceCents, currency: c.currency)})';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.transfer, style: const TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<int>(
              key: const ValueKey('editar-origen'),
              initialValue: _cuentas.any((c) => c.localId == _origen) ? _origen : null,
              decoration: InputDecoration(labelText: context.l10n.from2),
              items: [for (final c in _cuentas) DropdownMenuItem(value: c.localId, child: Text(label(c)))],
              onChanged: (v) => setState(() {
                _origen = v;
                if (_destino == v) _destino = null;
              }),
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('editar-destino-$_origen'),
              initialValue: destinos.any((c) => c.localId == _destino) ? _destino : null,
              decoration: InputDecoration(labelText: context.l10n.to2),
              items: [for (final c in destinos) DropdownMenuItem(value: c.localId, child: Text(label(c)))],
              onChanged: (v) => setState(() => _destino = v),
            ),
            TextField(
              key: const ValueKey('editar-monto-transferencia'),
              controller: _montoTransfer,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.l10n.amount, prefixText: '${origen?.currency.symbol ?? r'$'} '),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              key: const ValueKey('guardar-transferencia'),
              onPressed: _saveTransfer,
              child: Text(context.l10n.saveTransfer),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un renglón editable: concepto, categoría (no en ingresos) y monto positivo.
class _DetailEditor extends StatefulWidget {
  final EditableDetail detail;
  final bool isIncome;
  final bool enabled;
  final List<LocalCategory> categorias;
  final Future<void> Function(String concept, int? category, int? amountCents) onSave;
  final VoidCallback onDelete;

  const _DetailEditor({
    super.key,
    required this.detail,
    required this.isIncome,
    required this.enabled,
    required this.categorias,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_DetailEditor> createState() => _DetailEditorState();
}

class _DetailEditorState extends State<_DetailEditor> {
  late final _concept = TextEditingController(text: widget.detail.concept ?? '');
  late final _amount = TextEditingController(text: Money.toApiDecimal(widget.detail.amountCents.abs()).replaceAll('.', ','));
  late int? _category = widget.detail.categoryLocalId;

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final hasCategory = widget.categorias.any((c) => c.localId == _category);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${d.accountName.toUpperCase()} · ${Money.format(d.amountCents, currency: d.currency)}',
                style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
            TextField(
              controller: _concept,
              enabled: widget.enabled,
              maxLength: conceptMax,
              decoration: InputDecoration(labelText: context.l10n.concept, counterText: ''),
            ),
            if (!widget.isIncome && hasCategory)
              DropdownButtonFormField<int>(
                initialValue: _category,
                decoration: InputDecoration(labelText: context.l10n.category),
                items: [for (final c in widget.categorias) DropdownMenuItem(value: c.localId, child: Text(c.name))],
                onChanged: widget.enabled ? (v) => setState(() => _category = v) : null,
              )
            else if (d.categoryName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${context.l10n.category}: ${d.categoryName}', style: const TextStyle(fontSize: 12)),
              ),
            TextField(
              key: ValueKey('monto-renglon-${d.localId}'),
              controller: _amount,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.l10n.amount, prefixText: '${d.currency.symbol} '),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: ValueKey('borrar-renglon-${d.localId}'),
                  onPressed: widget.enabled ? widget.onDelete : null,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                  label: Text(context.l10n.deleteLine, style: const TextStyle(color: AppColors.rose)),
                ),
                TextButton.icon(
                  key: ValueKey('guardar-renglon-${d.localId}'),
                  onPressed: widget.enabled ? () => widget.onSave(_concept.text, widget.isIncome ? null : _category, Money.parseInput(_amount.text)) : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(context.l10n.saveLine),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
