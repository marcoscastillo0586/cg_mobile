import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../data/reports_repository.dart';
import '../../domain/entities/product_price_entity.dart';
import '../providers/analytics_notifier.dart';
import '../../../../l10n/l10n.dart';

class ProductPriceTrackerView extends ConsumerStatefulWidget {
  const ProductPriceTrackerView({super.key});

  @override
  ConsumerState<ProductPriceTrackerView> createState() => _ProductPriceTrackerViewState();
}

class _ProductPriceTrackerViewState extends ConsumerState<ProductPriceTrackerView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      unawaited(ref.read(analyticsNotifierProvider.notifier).cargarPreciosProductos());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirHistorialProducto(ProductPriceItemEntity item) async {
    AppFeedback.selection();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPriceHistorySheet(concepto: item.concepto, plu: item.plu),
    );
  }


  void _abrirComparadorInflacion() {
    AppFeedback.selection();
    showDialog<void>(
      context: context,
      builder: (ctx) => const _InflationComparisonDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Barra de Búsqueda y Botón de Comparador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar artículo o código PLU...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(analyticsNotifierProvider.notifier).buscarPrecios('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    ref.read(analyticsNotifierProvider.notifier).buscarPrecios(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.compare_arrows_rounded),
                tooltip: 'Comparar Inflación entre Períodos',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _abrirComparadorInflacion,
              ),
            ],
          ),
        ),

        // Lista de Productos
        Expanded(
          child: Builder(
            builder: (context) {
              if (state.isLoadingPrecios && state.productosPrecios.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.productosPrecios.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.lightTextSecondary),
                      SizedBox(height: 12),
                      Text(
                        'No se encontraron artículos registrados',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Los artículos se registran al cargar tickets o egresos detallados',
                        style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }


              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: state.productosPrecios.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = state.productosPrecios[index];
                  final haAumentado = item.variacionPorcentaje > 0;
                  final esIgual = item.variacionPorcentaje == 0;
                  final colorVar = esIgual
                      ? AppColors.lightTextSecondary
                      : (haAumentado ? AppColors.rose : AppColors.emerald);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _abrirHistorialProducto(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            // Icono representativo
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (haAumentado ? AppColors.rose : AppColors.primary)
                                    .withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.shopping_basket_rounded,
                                color: haAumentado ? AppColors.rose : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Nombre del Producto y compras
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.concepto,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${item.totalCompras} ${item.totalCompras == 1 ? "compra" : "compras"}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                      ),
                                      if (item.ultimoLugar.isNotEmpty) ...[
                                        const Text(' • ', style: TextStyle(color: AppColors.lightTextSecondary)),
                                        Expanded(
                                          child: Text(
                                            item.ultimoLugar,
                                            style: const TextStyle(
                                                fontSize: 12, color: AppColors.lightTextSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Precio Actual y Variación
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Money.format(item.ultimoPrecioCents),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorVar.withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        haAumentado
                                            ? Icons.trending_up_rounded
                                            : (esIgual
                                                ? Icons.trending_flat_rounded
                                                : Icons.trending_down_rounded),
                                        size: 14,
                                        color: colorVar,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${haAumentado ? "+" : ""}${item.variacionPorcentaje.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colorVar,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20, color: AppColors.lightTextSecondary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Modal que muestra el gráfico de evolución cronológica de precios del producto
class _ProductPriceHistorySheet extends ConsumerStatefulWidget {
  final String concepto;
  final String? plu;

  const _ProductPriceHistorySheet({required this.concepto, this.plu});

  @override
  ConsumerState<_ProductPriceHistorySheet> createState() => _ProductPriceHistorySheetState();
}

class _ProductPriceHistorySheetState extends ConsumerState<_ProductPriceHistorySheet> {
  bool _isLoading = true;
  ProductPriceHistoryEntity? _history;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repository = ref.read(reportsRepositoryProvider);
      try {
        // Con PLU se agrupa el producto exacto; sin PLU, por concepto.
        final res = await repository.getProductHistory(
          concept: widget.plu == null ? widget.concepto : null,
          plu: widget.plu,
        );
        if (mounted) {
          setState(() {
            _history = res;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('[REPORTES] Historial de producto: $e');
        if (mounted) {
          setState(() {
            _error = e;
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),

      child: Column(
        children: [
          // Barra de agarre
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.concepto,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Historial de Precios y Tendencia',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            ErrorMessages.describe(_error!, context.l10n) +
                                (ErrorMessages.codeOf(_error!) != null ? ' (${ErrorMessages.codeOf(_error!)})' : ''),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _history == null || _history!.historial.isEmpty
                    ? const Center(child: Text('No hay datos históricos para este artículo'))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // 4 Tarjetas de Métricas de Precio
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  'Precio Actual',
                                  Money.format(_history!.precioActualCents),
                                  AppColors.primary,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  'Variación Total',
                                  '${_history!.aumentoPorcentaje > 0 ? "+" : ""}${_history!.aumentoPorcentaje.toStringAsFixed(1)}%',
                                  _history!.aumentoPorcentaje > 0 ? AppColors.rose : AppColors.emerald,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  'Mínimo Histórico',
                                  Money.format(_history!.precioMinimoCents),
                                  AppColors.emerald,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  'Máximo Histórico',
                                  Money.format(_history!.precioMaximoCents),
                                  AppColors.rose,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Gráfico de Tendencia de Precios
                          if (_history!.historial.length >= 2) ...[
                            const Text(
                              'Evolución del Precio Unitario',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 46,
                                        getTitlesWidget: (val, meta) => Text(
                                          '\$${val.toInt()}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.lightTextSecondary),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 22,
                                        getTitlesWidget: (val, meta) {
                                          final idx = val.toInt();
                                          if (idx < 0 || idx >= _history!.historial.length) {
                                            return const SizedBox();
                                          }
                                          final f = _history!.historial[idx].fechaHora.split(' ').first;
                                          final parts = f.split('-');
                                          final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : f;
                                          return Text(label, style: const TextStyle(fontSize: 9));
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: List.generate(_history!.historial.length, (i) {
                                        // Solo geometría del gráfico (el texto se formatea desde centavos).
                                        return FlSpot(i.toDouble(), _history!.historial[i].precioUnitarioCents / 100);
                                      }),
                                      isCurved: true,
                                      color: AppColors.primary,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Registro Cronológico de Compras
                          const Text(
                            'Historial de Compras',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          ..._history!.historial.reversed.map((compra) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  Money.format(compra.precioUnitarioCents),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${compra.fechaHora.split(' ').first} • ${compra.lugarNombre}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                ),
                                trailing: Text(
                                  'Total ${Money.format(compra.montoTotalCents)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// Diálogo interactivo para comparar inflación entre 2 períodos
class _InflationComparisonDialog extends ConsumerStatefulWidget {
  const _InflationComparisonDialog();

  @override
  ConsumerState<_InflationComparisonDialog> createState() => _InflationComparisonDialogState();
}

class _InflationComparisonDialogState extends ConsumerState<_InflationComparisonDialog> {
  late DateTime _desde1;
  late DateTime _hasta1;
  late DateTime _desde2;
  late DateTime _hasta2;

  bool _isComparing = false;
  Object? _compareError;
  PriceComparisonResultEntity? _result;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Periodo 1: Mes anterior
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    _desde1 = DateTime(prevMonth.year, prevMonth.month, 1);
    _hasta1 = DateTime(prevMonth.year, prevMonth.month + 1, 0);

    // Periodo 2: Mes actual
    _desde2 = DateTime(now.year, now.month, 1);
    _hasta2 = DateTime(now.year, now.month + 1, 0);

    Future.microtask(_ejecutarComparativa);
  }

  Future<void> _ejecutarComparativa() async {
    setState(() {
      _isComparing = true;
      _compareError = null;
    });
    final fmt = DateFormat('yyyy-MM-dd');
    try {
      final repository = ref.read(reportsRepositoryProvider);
      final res = await repository.compareProducts(
        from1: fmt.format(_desde1),
        to1: fmt.format(_hasta1),
        from2: fmt.format(_desde2),
        to2: fmt.format(_hasta2),
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isComparing = false;
        });
      }
    } catch (e) {
      debugPrint('[REPORTES] Comparativa de precios: $e');
      if (mounted) {
        setState(() {
          _compareError = e;
          _isComparing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.compare_arrows_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monitor de Inflación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Comparativa de artículos idénticos comprados',
                            style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 1),

            // Resultado
            Expanded(
              child: _isComparing
                  ? const Center(child: CircularProgressIndicator())
                  : _compareError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              ErrorMessages.describe(_compareError!, context.l10n) +
                                  (ErrorMessages.codeOf(_compareError!) != null ? ' (${ErrorMessages.codeOf(_compareError!)})' : ''),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                  : _result == null || _result!.comparativa.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No se detectaron artículos idénticos comprados en ambos períodos seleccionados.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Banner de Inflación Promedio
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (_result!.inflacionPromedio > 0 ? AppColors.rose : AppColors.emerald)
                                    .withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (_result!.inflacionPromedio > 0 ? AppColors.rose : AppColors.emerald)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _result!.inflacionPromedio > 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    size: 36,
                                    color: _result!.inflacionPromedio > 0 ? AppColors.rose : AppColors.emerald,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Inflación Promedio Personal',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_result!.inflacionPromedio > 0 ? "+" : ""}${_result!.inflacionPromedio.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: _result!.inflacionPromedio > 0
                                                ? AppColors.rose
                                                : AppColors.emerald,
                                          ),
                                        ),
                                        Text(
                                          '${_result!.productosComunes} artículos comparados (${_result!.productosAumentaron} subieron de precio)',
                                          style: const TextStyle(
                                              fontSize: 11, color: AppColors.lightTextSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lista de productos comparados
                            const Text('Detalle por Artículo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            ..._result!.comparativa.map((item) {
                              final subio = item.porcentaje > 0;
                              final color = subio ? AppColors.rose : AppColors.emerald;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.producto,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Antes: ${Money.format(item.precio1Cents)} ➔ Ahora: ${Money.format(item.precio2Cents)}',
                                              style: const TextStyle(
                                                  fontSize: 12, color: AppColors.lightTextSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${subio ? "+" : ""}${item.porcentaje.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                              color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
