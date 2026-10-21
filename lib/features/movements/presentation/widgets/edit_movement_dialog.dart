import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../accounts_admin/presentation/providers/accounts_admin_notifier.dart';
import '../../../categories_admin/presentation/providers/categories_admin_notifier.dart';
import '../../../dashboard/presentation/providers/dashboard_notifier.dart';
import '../../domain/entities/movement_entity.dart';
import '../providers/movement_list_notifier.dart';

class EditMovementDialog extends ConsumerStatefulWidget {
  final MovementEntity movement;

  const EditMovementDialog({
    super.key,
    required this.movement,
  });

  @override
  ConsumerState<EditMovementDialog> createState() => _EditMovementDialogState();
}

class _EditMovementDialogState extends ConsumerState<EditMovementDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _conceptoController;
  late TextEditingController _montoController;
  late DateTime _fechaSeleccionada;

  int? _idLugar;
  int? _idCategoria;
  int? _idLugarOrigen;
  int? _idLugarDestino;

  final List<Map<String, dynamic>> _itemControllers = [];

  @override
  void initState() {
    super.initState();
    _conceptoController = TextEditingController(text: widget.movement.conceptoGeneral);
    _montoController = TextEditingController(text: widget.movement.monto.abs().toStringAsFixed(2));
    _fechaSeleccionada = DateTime.tryParse(widget.movement.fecha) ?? DateTime.now();

    _idLugar = widget.movement.idLugar > 0 ? widget.movement.idLugar : null;
    _idCategoria = widget.movement.idCategoria > 0 ? widget.movement.idCategoria : null;

    Future.microtask(() async {
      unawaited(ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas());
      unawaited(ref.read(categoriesAdminNotifierProvider.notifier).cargarCategorias());

      final detail = await ref
          .read(movementListNotifierProvider.notifier)
          .obtenerDetalle(widget.movement.idMovimientoEnc);

      if (mounted) {
        setState(() {
          _isLoading = false;

          if (detail != null) {
            _conceptoController.text = detail.conceptoGeneral;
            _montoController.text = detail.montoTotal.toStringAsFixed(2);
            _fechaSeleccionada = DateTime.tryParse(detail.fecha) ?? _fechaSeleccionada;

            if (detail.isTransfer) {
              _idLugarOrigen = detail.idLugarOrigen;
              _idLugarDestino = detail.idLugarDestino;
            } else if (detail.detalles.isNotEmpty) {
              _idLugar = detail.detalles.first.idLugar;
              _idCategoria = detail.detalles.first.idCategoria;

              for (final d in detail.detalles) {
                _itemControllers.add({
                  'id_movimiento_det': d.idMovimientoDet,
                  'concepto': TextEditingController(text: d.concepto),
                  'monto': TextEditingController(text: d.monto.toStringAsFixed(2)),
                  'id_categoria': d.idCategoria,
                  'id_lugar': d.idLugar,
                });
              }
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    for (final item in _itemControllers) {
      (item['concepto'] as TextEditingController).dispose();
      (item['monto'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Seleccionar fecha del movimiento',
    );

    if (seleccion != null) {
      setState(() {
        _fechaSeleccionada = DateTime(
          seleccion.year,
          seleccion.month,
          seleccion.day,
          _fechaSeleccionada.hour,
          _fechaSeleccionada.minute,
        );
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    AppFeedback.light();

    try {
      final fechaStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaSeleccionada);
      final monto = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;

      final body = <String, dynamic>{
        'id_movimiento_enc': widget.movement.idMovimientoEnc,
        'fecha': fechaStr,
        'concepto_general': _conceptoController.text.trim(),
      };

      if (widget.movement.tipoMovimiento == 1) {
        body['id_lugar'] = _idLugar;
        body['monto'] = monto;
      } else if (widget.movement.tipoMovimiento == 3) {
        body['id_lugar_origen'] = _idLugarOrigen;
        body['id_lugar_destino'] = _idLugarDestino;
        body['monto'] = monto;
      } else {
        body['id_lugar'] = _idLugar;
        if (_itemControllers.length > 1) {
          final listDet = <Map<String, dynamic>>[];
          for (final item in _itemControllers) {
            final cMonto = (item['monto'] as TextEditingController).text;
            final cConcepto = (item['concepto'] as TextEditingController).text;
            listDet.add({
              'id_movimiento_det': item['id_movimiento_det'],
              'id_categoria': item['id_categoria'],
              'id_lugar': _idLugar,
              'concepto': cConcepto.trim(),
              'monto': double.tryParse(cMonto.replaceAll(',', '.')) ?? 0.0,
            });
          }
          body['detalles'] = listDet;
        } else {
          body['id_categoria'] = _idCategoria;
          body['monto'] = monto;
        }
      }

      final ok = await ref.read(movementListNotifierProvider.notifier).actualizarMovimiento(body);

      if (ok && mounted) {
        unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard());
        Navigator.of(context).pop(true);
        AppFeedback.showSuccess(context, 'Movimiento actualizado correctamente');
      } else if (mounted) {
        AppFeedback.showError(context, 'No se pudo actualizar el movimiento');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Error al guardar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsAdminNotifierProvider);
    final categoriesState = ref.watch(categoriesAdminNotifierProvider);

    final tipo = widget.movement.tipoMovimiento;
    final tipoNombre = tipo == 1 ? 'Ingreso' : (tipo == 2 ? 'Egreso' : 'Transferencia');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(
              tipo == 1
                  ? Icons.arrow_downward_rounded
                  : (tipo == 2 ? Icons.arrow_upward_rounded : Icons.swap_horiz_rounded),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar $tipoNombre',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID #${widget.movement.idMovimientoEnc}',
                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando detalle del movimiento...'),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de Fecha
                    InkWell(
                      onTap: _seleccionarFecha,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha del Movimiento',
                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(_fechaSeleccionada),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Concepto General
                    TextFormField(
                      controller: _conceptoController,
                      decoration: InputDecoration(
                        labelText: 'Concepto / Descripción General',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa una descripción';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campos específicos según tipo de movimiento
                    if (tipo == 3) ...[
                      // TRANSFERENCIA
                      DropdownButtonFormField<int>(
                        initialValue: _idLugarOrigen,
                        decoration: InputDecoration(
                          labelText: 'Cuenta de Origen (Debita)',
                          prefixIcon: const Icon(Icons.outbox_rounded, color: AppColors.rose),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: accountsState.cuentas.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.idLugar,
                            child: Text(c.nombre),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _idLugarOrigen = val),
                        validator: (v) => v == null ? 'Selecciona cuenta de origen' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _idLugarDestino,
                        decoration: InputDecoration(
                          labelText: 'Cuenta de Destino (Acredita)',
                          prefixIcon: const Icon(Icons.inbox_rounded, color: AppColors.emerald),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: accountsState.cuentas.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.idLugar,
                            child: Text(c.nombre),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _idLugarDestino = val),
                        validator: (v) {
                          if (v == null) return 'Selecciona cuenta de destino';
                          if (v == _idLugarOrigen) return 'No puede ser igual al origen';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto Transferido (\$)',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                          if (n == null || n <= 0) return 'Ingresa un monto válido';
                          return null;
                        },
                      ),
                    ] else ...[
                      // EGRESO SIMPLE O INGRESO
                      DropdownButtonFormField<int>(
                        initialValue: _idLugar,
                        decoration: InputDecoration(
                          labelText: tipo == 1 ? 'Cuenta de Depósito' : 'Cuenta de Pago',
                          prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: accountsState.cuentas.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.idLugar,
                            child: Text(c.nombre),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _idLugar = val),
                        validator: (v) => v == null ? 'Selecciona una cuenta' : null,
                      ),
                      const SizedBox(height: 16),
                      if (tipo == 2) ...[
                        DropdownButtonFormField<int>(
                          initialValue: _idCategoria,
                          decoration: InputDecoration(
                            labelText: 'Categoría del Gasto',
                            prefixIcon: const Icon(Icons.category_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: categoriesState.categorias.map((cat) {
                            return DropdownMenuItem<int>(
                              value: cat.idCategoria,
                              child: Text(cat.nombre),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _idCategoria = val),
                          validator: (v) => v == null ? 'Selecciona una categoría' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto (\$)',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                          if (n == null || n <= 0) return 'Ingresa un monto válido mayor a 0';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_isSaving || _isLoading) ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
