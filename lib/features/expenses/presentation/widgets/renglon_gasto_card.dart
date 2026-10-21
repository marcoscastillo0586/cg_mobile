import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/renglon_gasto.dart';

class RenglonGastoCard extends StatefulWidget {
  final int index;
  final RenglonGasto renglon;
  final List<CategoryEntity> categorias;
  final List<String> sugerenciasConcepto;
  final bool canDelete;
  final VoidCallback onEliminar;
  final ValueChanged<String> onConceptoChanged;
  final ValueChanged<double> onMontoChanged;
  final ValueChanged<int> onCategoriaChanged;

  const RenglonGastoCard({
    super.key,
    required this.index,
    required this.renglon,
    required this.categorias,
    required this.sugerenciasConcepto,
    required this.canDelete,
    required this.onEliminar,
    required this.onConceptoChanged,
    required this.onMontoChanged,
    required this.onCategoriaChanged,
  });

  @override
  State<RenglonGastoCard> createState() => _RenglonGastoCardState();
}

class _RenglonGastoCardState extends State<RenglonGastoCard> {
  late final TextEditingController _conceptoController;
  late final TextEditingController _montoController;
  late final FocusNode _conceptoFocusNode;
  late final FocusNode _montoFocusNode;

  @override
  void initState() {
    super.initState();
    _conceptoController = TextEditingController(text: widget.renglon.concepto);
    _montoController = TextEditingController(
      text: widget.renglon.monto > 0
          ? (widget.renglon.monto % 1 == 0
              ? widget.renglon.monto.toInt().toString()
              : widget.renglon.monto.toStringAsFixed(2))
          : '',
    );
    _conceptoFocusNode = FocusNode();
    _montoFocusNode = FocusNode();

    _conceptoFocusNode.addListener(() {
      if (!_conceptoFocusNode.hasFocus) {
        widget.onConceptoChanged(_conceptoController.text.trim());
      }
    });
  }

  @override
  void didUpdateWidget(covariant RenglonGastoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si el concepto cambió externamente (ej: escaneo QR o sugerencia) y no tiene foco activo
    if (widget.renglon.concepto != _conceptoController.text && !_conceptoFocusNode.hasFocus) {
      _conceptoController.text = widget.renglon.concepto;
    }

    // Si el monto cambió externamente (ej: escaneo QR) y no tiene foco activo
    final currentParsedMonto = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    if ((widget.renglon.monto - currentParsedMonto).abs() > 0.001 && !_montoFocusNode.hasFocus) {
      _montoController.text = widget.renglon.monto > 0
          ? (widget.renglon.monto % 1 == 0
              ? widget.renglon.monto.toInt().toString()
              : widget.renglon.monto.toStringAsFixed(2))
          : '';
    }
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    _conceptoFocusNode.dispose();
    _montoFocusNode.dispose();
    super.dispose();
  }

  void _onMontoChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    widget.onMontoChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renglonNum = widget.index + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del renglón (Número y Botón de eliminar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Renglón #$renglonNum',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.rose,
                      size: 20,
                    ),
                    tooltip: 'Eliminar renglón',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onEliminar,
                  )
                else
                  const SizedBox(
                    width: 20,
                    height: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Campo: Concepto del renglón
            const Text(
              'Concepto',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: widget.renglon.concepto),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.sugerenciasConcepto.where((String item) {
                  return item.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _conceptoController.text = selection;
                widget.onConceptoChanged(selection);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sincronizar controller de autocomplete con el local
                controller.addListener(() {
                  if (_conceptoController.text != controller.text) {
                    _conceptoController.text = controller.text;
                    widget.onConceptoChanged(controller.text);
                  }
                });

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ej: Verduras, Carne, Limpieza...',
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              controller.clear();
                              _conceptoController.clear();
                              widget.onConceptoChanged('');
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Fila: Monto y Categoría
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Monto
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monto',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _montoController,
                        focusNode: _montoFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: _onMontoChanged,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: '0,00',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Columna Categoría
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: widget.renglon.categoriaId,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Categoría', style: TextStyle(fontSize: 13)),
                            items: widget.categorias.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat.idCategoria,
                                child: Text(
                                  cat.nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                widget.onCategoriaChanged(val);
                              }
                            },
                          ),
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
    );
  }
}
