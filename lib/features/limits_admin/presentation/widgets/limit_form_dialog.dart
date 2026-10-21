import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../accounts_admin/data/datasources/accounts_admin_remote_data_source.dart';
import '../../../categories_admin/data/datasources/categories_admin_remote_data_source.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/expense_limit_admin_entity.dart';

class LimitFormDialog extends ConsumerStatefulWidget {
  final ExpenseLimitAdminEntity? limit;
  final Future<bool> Function({
    required DateTime desde,
    required DateTime hasta,
    required double montoLimite,
    required List<int> categoriasIds,
    required List<int> lugaresIds,
  }) onGuardar;

  const LimitFormDialog({
    super.key,
    this.limit,
    required this.onGuardar,
  });

  @override
  ConsumerState<LimitFormDialog> createState() => _LimitFormDialogState();
}

class _LimitFormDialogState extends ConsumerState<LimitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();

  late DateTime _desde;
  late DateTime _hasta;

  final Set<int> _selectedCategorias = {};
  final Set<int> _selectedLugares = {};

  List<({int id, String nombre})> _availableCategorias = [];
  List<({int id, String nombre})> _availableLugares = [];

  bool _isLoadingCatalogs = true;
  bool _isSaving = false;
  String? _catalogError;
  String? _validationError;
  Timer? _errorTimer;

  bool get isEditing => widget.limit != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.limit != null) {
      _desde = widget.limit!.desde;
      _hasta = widget.limit!.hasta;
      _montoController.text = widget.limit!.montoLimite > 0
          ? widget.limit!.montoLimite.toStringAsFixed(0)
          : '';
      _selectedCategorias.addAll(widget.limit!.categoriasIds);
      _selectedLugares.addAll(widget.limit!.lugaresIds);
    } else {
      _desde = DateTime(now.year, now.month, 1);
      _hasta = DateTime(now.year, now.month + 1, 0);
    }

    _cargarCatalogos();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final catSource = ref.read(categoriesAdminRemoteDataSourceProvider);
      final lugSource = ref.read(accountsAdminRemoteDataSourceProvider);

      final results = await Future.wait([
        catSource.getCategories(todas: false),
        lugSource.getAccounts(todos: false),
      ]);

      final cats = results[0] as List;
      final lugs = results[1] as List;

      if (mounted) {
        setState(() {
          _availableCategorias = cats
              .map((c) => (
                    id: (c as dynamic).idCategoria as int,
                    nombre: (c as dynamic).nombre as String,
                  ))
              .toList();

          _availableLugares = lugs
              .map((l) => (
                    id: (l as dynamic).idLugar as int,
                    nombre: (l as dynamic).nombre as String,
                  ))
              .toList();

          _isLoadingCatalogs = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error en _cargarCatalogos: $e\n$stack');
      if (mounted) {
        setState(() {
          _catalogError = 'No se pudieron cargar rubros y cuentas: $e';
          _isLoadingCatalogs = false;
        });
      }
    }
  }

  void _seleccionarDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Fecha de inicio del límite',
    );
    if (picked != null) {
      AppFeedback.selection();
      setState(() {
        _desde = picked;
        if (_hasta.isBefore(_desde)) {
          _hasta = DateTime(_desde.year, _desde.month + 1, 0);
        }
      });
    }
  }

  void _seleccionarHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta.isBefore(_desde) ? _desde : _hasta,
      firstDate: _desde,
      lastDate: DateTime(2035),
      helpText: 'Fecha de vencimiento del límite',
    );
    if (picked != null) {
      AppFeedback.selection();
      setState(() => _hasta = picked);
    }
  }

  void _mostrarErrorModal(String mensaje) {
    setState(() => _validationError = mensaje);
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _validationError = null);
      }
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategorias.isEmpty) {
      _mostrarErrorModal('Debes seleccionar al menos una categoría');
      return;
    }

    if (_selectedLugares.isEmpty) {
      _mostrarErrorModal('Debes seleccionar al menos una cuenta');
      return;
    }

    final monto = double.tryParse(_montoController.text.trim()) ?? 0.0;
    if (monto <= 0) {
      _mostrarErrorModal('El monto debe ser mayor a 0');
      return;
    }

    setState(() => _isSaving = true);
    AppFeedback.light();

    final ok = await widget.onGuardar(
      desde: _desde,
      hasta: _hasta,
      montoLimite: monto,
      categoriasIds: _selectedCategorias.toList(),
      lugaresIds: _selectedLugares.toList(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final isEn = settings.language == 'en';

    final tituloModal = isEditing
        ? (isEn ? 'Edit Limit' : 'Editar límite')
        : (isEn ? 'New Limit' : 'Nuevo límite');
    final textoBoton = isEditing
        ? 'Guardar cambios'
        : (isEn ? 'Create Limit' : 'Crear límite');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_calendar_rounded : Icons.add_chart_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tituloModal,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Scrollable Form Content
              Expanded(
                child: _isLoadingCatalogs
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Cargando categorías y cuentas...'),
                          ],
                        ),
                      )
                    : _catalogError != null
                        ? Center(
                            child: Text(
                              _catalogError!,
                              style: const TextStyle(color: AppColors.rose),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Campo Monto
                                  Text(
                                    'Monto Límite del Presupuesto',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _montoController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
                                      hintText: '0.00',
                                      filled: true,
                                      fillColor: isDark
                                          ? AppColors.darkBg
                                          : AppColors.primary.withValues(alpha: 0.04),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: isDark ? Colors.white12 : Colors.black12,
                                        ),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Ingresa el monto del presupuesto';
                                      }
                                      final numVal = double.tryParse(val.trim());
                                      if (numVal == null || numVal <= 0) {
                                        return 'El monto debe ser un número mayor a cero';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Fechas Desde y Hasta
                                  Text(
                                    'Período de Control',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: _seleccionarDesde,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark ? Colors.white12 : Colors.black12,
                                              ),
                                              color: isDark ? AppColors.darkSurface : Colors.white,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Desde',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      AppDateUtils.formatDate(_desde),
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _seleccionarHasta,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark ? Colors.white12 : Colors.black12,
                                              ),
                                              color: isDark ? AppColors.darkSurface : Colors.white,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Hasta (Vence)',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.event_available_rounded, size: 14, color: AppColors.primary),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      AppDateUtils.formatDate(_hasta),
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Selector de Categorías
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Categorías aplicables (${_selectedCategorias.length})',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          AppFeedback.selection();
                                          setState(() {
                                            if (_selectedCategorias.length == _availableCategorias.length) {
                                              _selectedCategorias.clear();
                                            } else {
                                              _selectedCategorias.addAll(_availableCategorias.map((c) => c.id));
                                            }
                                          });
                                        },
                                        child: Text(
                                          _selectedCategorias.length == _availableCategorias.length
                                              ? 'Desmarcar todas'
                                              : 'Seleccionar todas',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _availableCategorias.map((cat) {
                                      final isSelected = _selectedCategorias.contains(cat.id);
                                      return FilterChip(
                                        label: Text(cat.nombre),
                                        selected: isSelected,
                                        selectedColor: AppColors.primary.withValues(alpha: 0.18),
                                        checkmarkColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        onSelected: (val) {
                                          AppFeedback.selection();
                                          setState(() {
                                            if (val) {
                                              _selectedCategorias.add(cat.id);
                                            } else {
                                              _selectedCategorias.remove(cat.id);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 18),

                                  // Selector de Cuentas / Lugares
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Cuentas incluidas (${_selectedLugares.length})',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          AppFeedback.selection();
                                          setState(() {
                                            if (_selectedLugares.length == _availableLugares.length) {
                                              _selectedLugares.clear();
                                            } else {
                                              _selectedLugares.addAll(_availableLugares.map((l) => l.id));
                                            }
                                          });
                                        },
                                        child: Text(
                                          _selectedLugares.length == _availableLugares.length
                                              ? 'Desmarcar todas'
                                              : 'Todas las cuentas',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _availableLugares.map((lug) {
                                      final isSelected = _selectedLugares.contains(lug.id);
                                      return FilterChip(
                                        label: Text(lug.nombre),
                                        selected: isSelected,
                                        selectedColor: AppColors.emerald.withValues(alpha: 0.18),
                                        checkmarkColor: AppColors.emerald,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? AppColors.emerald
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        onSelected: (val) {
                                          AppFeedback.selection();
                                          setState(() {
                                            if (val) {
                                              _selectedLugares.add(lug.id);
                                            } else {
                                              _selectedLugares.remove(lug.id);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Validation Error Message (immediately above buttons)
              if (_validationError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(
                      color: AppColors.rose,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isSaving || _isLoadingCatalogs) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52), // <-- Añadido estrictamente (Condición 1)
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            textoBoton,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
