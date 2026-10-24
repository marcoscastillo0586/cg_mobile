import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../../../l10n/l10n.dart';

class RenglonGastoCard extends StatefulWidget {
  final int index;
  final RenglonGasto renglon;
  final List<LocalCategory> categorias;
  final List<String> sugerenciasConcepto;
  final bool canDelete;
  final VoidCallback onEliminar;
  final ValueChanged<String> onConceptoChanged;
  /// Centavos; 0 si el texto no es un importe válido.
  final ValueChanged<int> onMontoChanged;
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
    _montoController = TextEditingController(text: _textoMonto(widget.renglon.montoCents));
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
    final actual = Money.parseInput(_montoController.text) ?? 0;
    if (widget.renglon.montoCents != actual && !_montoFocusNode.hasFocus) {
      _montoController.text = _textoMonto(widget.renglon.montoCents);
    }
  }

  /// Centavos → texto editable ("1500" o "1500,50"), sin pasar por double.
  static String _textoMonto(int cents) {
    if (cents <= 0) return '';
    final frac = cents % 100;
    return frac == 0 ? '${cents ~/ 100}' : '${cents ~/ 100},${frac.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    _conceptoFocusNode.dispose();
    _montoFocusNode.dispose();
    super.dispose();
  }

  bool _montoInvalido = false;

  void _onMontoChanged(String value) {
    final cents = Money.parseInput(value);
    setState(() => _montoInvalido = value.trim().isNotEmpty && cents == null);
    widget.onMontoChanged(cents ?? 0);
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
                        context.l10n.lineRenglonnum(renglonNum),
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
                    tooltip: context.l10n.deleteLine2,
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
            Text(
              context.l10n.concept,
              style: const TextStyle(
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
                    hintText: context.l10n.eGVegetablesMeatCleaning,
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
                      Text(
                        context.l10n.amount,
                        style: const TextStyle(
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
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: '0,00',
                          errorText: _montoInvalido ? context.l10n.invalidAmountMax2Decimals : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      Text(
                        context.l10n.category,
                        style: const TextStyle(
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
                            hint: Text(context.l10n.category, style: const TextStyle(fontSize: 13)),
                            items: widget.categorias.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat.localId,
                                child: Text(
                                  cat.name,
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
