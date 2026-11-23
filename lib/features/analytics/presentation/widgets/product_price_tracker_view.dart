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
import '../report_currency.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

/// Variación con signo: "+12.5%", "-3.0%", "0.0%".
@visibleForTesting
String variacion(num porcentaje) => '${porcentaje > 0 ? '+' : ''}${porcentaje.toStringAsFixed(1)}%';

/// Rojo si subió, verde si bajó; gris si no cambió (solo en la lista).
Color _colorVariacion(num porcentaje, {Color igual = AppColors.emerald}) =>
    porcentaje > 0 ? AppColors.rose : (porcentaje == 0 ? igual : AppColors.emerald);

/// "2026-11-10 10:00:00" → "10/11" (eje del gráfico).
@visibleForTesting
String diaMes(String fechaHora) {
  final f = fechaHora.split(' ').first;
  final parts = f.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}' : f;
}

/// Mes anterior y mes actual: los períodos que compara el monitor de inflación.
@visibleForTesting
((DateTime, DateTime), (DateTime, DateTime)) periodosInflacion(DateTime now) => (
      (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
      (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
    );

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
    Future.microtask(() => unawaited(ref.read(analyticsNotifierProvider.notifier).cargarPreciosProductos()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirHistorial(ProductPriceItemEntity item) {
    AppFeedback.selection();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPriceHistorySheet(concepto: item.concepto, plu: item.plu),
    );
  }

  void _abrirComparador() {
    AppFeedback.selection();
    showDialog<void>(context: context, builder: (ctx) => const _InflationComparisonDialog());
  }

  void _buscar(String texto) => ref.read(analyticsNotifierProvider.notifier).buscarPrecios(texto);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsNotifierProvider);
    final productos = state.productosPrecios;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('buscar-precios'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchItemPluCode,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _buscar('');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: _buscar,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.compare_arrows_rounded),
                tooltip: context.l10n.compareInflationBetweenPeriods,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _abrirComparador,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch ((state.isLoadingPrecios, productos.isEmpty)) {
            (true, true) => const Center(child: CircularProgressIndicator()),
            (false, true) => const _SinProductos(),
            _ => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).withBottomSafeArea(context),
                itemCount: productos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _ProductoCard(item: productos[index], onTap: () => _abrirHistorial(productos[index])),
              ),
          },
        ),
      ],
    );
  }
}

class _SinProductos extends StatelessWidget {
  const _SinProductos();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.lightTextSecondary),
            const SizedBox(height: 12),
            Text(context.l10n.noRecordedItemsFound, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              context.l10n.itemsRecordedWhenYouEnter,
              style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// Producto con compras, último lugar, último precio y variación.
class _ProductoCard extends StatelessWidget {
  final ProductPriceItemEntity item;
  final VoidCallback onTap;
  const _ProductoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subio = item.haAumentado;
    final acento = subio ? AppColors.rose : AppColors.primary;
    const gris = TextStyle(fontSize: 12, color: AppColors.lightTextSecondary);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: acento.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.shopping_basket_rounded, color: acento, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.concepto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      [context.l10n.purchasesCount(item.totalCompras), if (item.ultimoLugar.isNotEmpty) item.ultimoLugar].join(' • '),
                      style: gris,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Money.format(item.ultimoPrecioCents, currency: reportCurrency(context)), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  _Variacion(porcentaje: item.variacionPorcentaje),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de variación con flecha (sube / igual / baja).
class _Variacion extends StatelessWidget {
  final num porcentaje;
  const _Variacion({required this.porcentaje});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _colorVariacion(porcentaje, igual: AppColors.lightTextSecondary);
    final icon = porcentaje > 0 ? Icons.trending_up_rounded : (porcentaje == 0 ? Icons.trending_flat_rounded : Icons.trending_down_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.2 : 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(variacion(porcentaje), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// Consulta al repositorio con espera, error (motivo y código) o resultado.
class _Consulta<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final bool Function(T value) vacio;
  final String textoVacio;
  final Widget Function(T value) builder;
  const _Consulta({required this.snapshot, required this.vacio, required this.textoVacio, required this.builder});

  @override
  Widget build(BuildContext context) {
    final error = snapshot.error;
    final data = snapshot.data;
    Widget centrado(String texto) =>
        Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(texto, textAlign: TextAlign.center)));
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (error != null) return centrado(ErrorMessages.withCode(error, context.l10n));
    if (data == null || vacio(data)) return centrado(textoVacio);
    return builder(data);
  }
}

/// Historial de precios de un producto: indicadores, gráfico y compras.
class _ProductPriceHistorySheet extends ConsumerStatefulWidget {
  final String concepto;
  final String? plu;

  const _ProductPriceHistorySheet({required this.concepto, this.plu});

  @override
  ConsumerState<_ProductPriceHistorySheet> createState() => _ProductPriceHistorySheetState();
}

class _ProductPriceHistorySheetState extends ConsumerState<_ProductPriceHistorySheet> {
  late final Future<ProductPriceHistoryEntity> _history;

  @override
  void initState() {
    super.initState();
    // Con PLU se agrupa el producto exacto; sin PLU, por concepto.
    _history = ref.read(reportsRepositoryProvider).getProductHistory(concept: widget.plu == null ? widget.concepto : null, plu: widget.plu)
      ..catchError((Object e) {
        debugPrint('[REPORTES] Historial de producto: $e');
        throw e;
      }).ignore();
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
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.concepto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(context.l10n.priceHistoryTrend, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: _history,
              builder: (context, snapshot) => _Consulta(
                snapshot: snapshot,
                vacio: (h) => h.historial.isEmpty,
                textoVacio: context.l10n.noHistoricalDataItem,
                builder: (h) => _Historial(history: h),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  final ProductPriceHistoryEntity history;
  const _Historial({required this.history});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currency = reportCurrency(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const titulo = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);
    Widget par(_Kpi a, _Kpi b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    return ListView(
      padding: const EdgeInsets.all(20).withBottomSafeArea(context),
      children: [
        par(
          _Kpi(l10n.currentPrice, Money.format(history.precioActualCents, currency: currency), AppColors.primary),
          _Kpi(l10n.totalChange, variacion(history.aumentoPorcentaje), _colorVariacion(history.aumentoPorcentaje)),
        ),
        const SizedBox(height: 10),
        par(
          _Kpi(l10n.historicalLow, Money.format(history.precioMinimoCents, currency: currency), AppColors.emerald),
          _Kpi(l10n.historicalHigh, Money.format(history.precioMaximoCents, currency: currency), AppColors.rose),
        ),
        const SizedBox(height: 24),
        if (history.historial.length >= 2) ...[
          Text(l10n.unitPriceTrend, style: titulo),
          const SizedBox(height: 14),
          SizedBox(height: 180, child: _GraficoPrecios(compras: history.historial)),
          const SizedBox(height: 24),
        ],
        Text(l10n.purchaseHistory, style: titulo),
        const SizedBox(height: 10),
        for (final compra in history.historial.reversed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: ListTile(
              dense: true,
              title: Text(Money.format(compra.precioUnitarioCents, currency: currency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${compra.fechaHora.split(' ').first} • ${compra.lugarNombre}', style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
              trailing: Text('Total ${Money.format(compra.montoTotalCents, currency: currency)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

/// Precio unitario de cada compra, en orden.
class _GraficoPrecios extends StatelessWidget {
  final List<ProductPurchaseHistoryItemEntity> compras;
  const _GraficoPrecios({required this.compras});

  Widget _fecha(double val, TitleMeta meta) {
    final idx = val.toInt();
    return idx < 0 || idx >= compras.length ? const SizedBox() : Text(diaMes(compras[idx].fechaHora), style: const TextStyle(fontSize: 9));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (val, meta) => Text('\$${val.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.lightTextSecondary)),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: _fecha)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            // Solo geometría del gráfico (el texto se formatea desde centavos).
            spots: [for (final (i, c) in compras.indexed) FlSpot(i.toDouble(), c.precioUnitarioCents / 100)],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _Kpi(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

/// Monitor de inflación: los mismos productos comprados el mes anterior y este mes.
class _InflationComparisonDialog extends ConsumerStatefulWidget {
  const _InflationComparisonDialog();

  @override
  ConsumerState<_InflationComparisonDialog> createState() => _InflationComparisonDialogState();
}

class _InflationComparisonDialogState extends ConsumerState<_InflationComparisonDialog> {
  late final Future<PriceComparisonResultEntity> _result;

  @override
  void initState() {
    super.initState();
    final fmt = DateFormat('yyyy-MM-dd');
    final ((desde1, hasta1), (desde2, hasta2)) = periodosInflacion(DateTime.now());
    _result = ref
        .read(reportsRepositoryProvider)
        .compareProducts(from1: fmt.format(desde1), to1: fmt.format(hasta1), from2: fmt.format(desde2), to2: fmt.format(hasta2))
      ..catchError((Object e) {
        debugPrint('[REPORTES] Comparativa de precios: $e');
        throw e;
      }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.compare_arrows_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.inflationMonitor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(context.l10n.comparisonIdenticalItemsPurchased, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder(
                future: _result,
                builder: (context, snapshot) => _Consulta(
                  snapshot: snapshot,
                  vacio: (r) => r.comparativa.isEmpty,
                  textoVacio: context.l10n.noIdenticalItemsWerePurchased,
                  builder: (r) => _Comparacion(result: r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Comparacion extends StatelessWidget {
  final PriceComparisonResultEntity result;
  const _Comparacion({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = reportCurrency(context);
    final color = _colorVariacion(result.inflacionPromedio);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(result.inflacionPromedio > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 36, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.personalAverageInflation, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(variacion(result.inflacionPromedio), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                    Text(
                      context.l10n.productoscomunesItemsComparedProductosaumentaronWent(result.productosComunes, result.productosAumentaron),
                      style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.detailItem, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final item in result.comparativa)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.producto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.beforePrecio1centsNowPrecio2cents(
                              Money.format(item.precio1Cents, currency: currency), Money.format(item.precio2Cents, currency: currency)),
                          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _colorVariacion(item.porcentaje).withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(variacion(item.porcentaje), style: TextStyle(color: _colorVariacion(item.porcentaje), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
