import 'package:flutter/material.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/form_screen_theme.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../../../l10n/l10n.dart';
import 'egreso_estilo.dart';
import 'egreso_field_box.dart';

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
    final t = FormScreenTheme.of(context);
    final e = EgresoEstilo.of(context);
    final renglonNum = widget.index + 1;
    bool activa(Set<WidgetState> s) => s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16),
      decoration: e.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del renglón (insignia "Renglón #N" y papelera), con línea debajo.
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: e.separador))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: e.insigniaFondo,
                      borderRadius: BorderRadius.circular(FormScreenTheme.badgeRadius),
                      border: Border.all(color: e.insigniaBorde),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded, size: 14, color: e.insigniaTexto),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.l10n.lineRenglonnum(renglonNum),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.insigniaTexto),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: context.l10n.deleteLine2,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: ButtonStyle(
                      // Círculo de 32 px, sin el área de toque mínima de 48 px: la cabecera no crece.
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
                      fixedSize: const WidgetStatePropertyAll(Size(32, 32)),
                      shape: const WidgetStatePropertyAll(CircleBorder()),
                      // Gris; rosa sobre rosa claro al presionar.
                      foregroundColor: WidgetStateProperty.resolveWith((s) => activa(s) ? e.papeleraActiva : e.papelera),
                      backgroundColor: WidgetStateProperty.resolveWith((s) => activa(s) ? e.papeleraActivaFondo : Colors.transparent),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    ),
                    onPressed: widget.onEliminar,
                  )
                else
                  const SizedBox(width: 32, height: 32),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Campo: Concepto del renglón
          Text(context.l10n.lineConcept.toUpperCase(), style: e.etiquetaInterna),
          const SizedBox(height: 6),
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

              return EgresoFieldBox(
                focusNode: focusNode,
                inner: true,
                stitch: true,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  style: e.textoInterno(13, FontWeight.w600),
                  decoration: EgresoFieldBox.input(
                    inner: true,
                    hint: context.l10n.eGVegetablesMeatCleaning,
                    hintColor: t.hint,
                    prefixIcon: Icon(Icons.notes_rounded, size: 16, color: e.iconoInterno),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 16, color: e.iconoInterno),
                            onPressed: () {
                              controller.clear();
                              _conceptoController.clear();
                              widget.onConceptoChanged('');
                            },
                          )
                        : null,
                  ).copyWith(
                    hintStyle: TextStyle(color: t.hint, fontSize: 13, fontWeight: FontWeight.w500),
                    contentPadding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Fila: Monto y Categoría (dos columnas)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.amount.toUpperCase(), style: e.etiquetaInterna),
                    const SizedBox(height: 6),
                    EgresoFieldBox(
                      focusNode: _montoFocusNode,
                      inner: true,
                      stitch: true,
                      error: _montoInvalido,
                      child: TextField(
                        controller: _montoController,
                        focusNode: _montoFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: _onMontoChanged,
                        style: e.textoInterno(14, FontWeight.w800),
                        decoration: EgresoFieldBox.input(
                          inner: true,
                          hint: '0,00',
                          hintColor: t.hint,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 6),
                            child: Text('\$', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: e.iconoInterno)),
                          ),
                        ).copyWith(
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          contentPadding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                        ),
                      ),
                    ),
                    if (_montoInvalido) ...[
                      const SizedBox(height: 4),
                      Text(context.l10n.invalidAmountMax2Decimals, style: TextStyle(fontSize: 11, color: t.accentStrong)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.category.toUpperCase(), style: e.etiquetaInterna),
                    const SizedBox(height: 6),
                    EgresoFieldBox(
                      inner: true,
                      stitch: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: widget.renglon.categoriaId,
                            isExpanded: true,
                            isDense: true,
                            borderRadius: BorderRadius.circular(FormScreenTheme.innerRadius),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: e.iconoInterno),
                            style: e.textoInterno(13, FontWeight.w600),
                            dropdownColor: t.surface,
                            hint: Text(context.l10n.category, style: TextStyle(fontSize: 13, color: t.hint)),
                            items: widget.categorias.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat.localId,
                                child: Text(cat.name, overflow: TextOverflow.ellipsis),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
