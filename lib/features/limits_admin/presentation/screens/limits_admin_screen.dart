import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../../core/database/local_catalog.dart';
import '../../../../core/sync/local_ops.dart';
import '../../../movements/presentation/local_write_feedback.dart';
import '../../data/local_budgets_repository.dart';
import '../../domain/budget.dart';
import '../providers/limits_admin_notifier.dart';
import '../providers/limits_admin_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

class LimitsAdminScreen extends ConsumerStatefulWidget {
  const LimitsAdminScreen({super.key});

  @override
  ConsumerState<LimitsAdminScreen> createState() => _LimitsAdminScreenState();
}

class _LimitsAdminScreenState extends ConsumerState<LimitsAdminScreen> {
  @override
  void initState() {
    super.initState();
    // Con conexión trae primero lo que cambió en el servidor; sin conexión muestra lo guardado.
    Future.microtask(() async {
      await ref.read(syncControllerProvider.notifier).refreshIfOnline();
      if (mounted) await ref.read(limitsAdminNotifierProvider.notifier).cargarLimites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(limitsAdminNotifierProvider);
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (syncFinished(prev, next)) ref.read(limitsAdminNotifierProvider.notifier).cargarLimites(silencioso: true);
    });
    final notifier = ref.read(limitsAdminNotifierProvider.notifier);

    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: state.filtroEstado == key,
          onSelected: (_) => notifier.setFiltroEstado(key),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.budgets),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarLimites)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nuevo-limite'),
        onPressed: () => _crear(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newBudget),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.cargarLimites,
        child: _body(state, chip),
      ),
    );
  }

  Widget _body(LimitsAdminState state, Widget Function(String, String) chip) {
    if (state.status == LimitsAdminStatus.loading && state.limits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LimitsAdminStatus.error && state.limits.isEmpty) {
      final error = state.error!;
      final code = ErrorMessages.codeOf(error);
      return ListView(children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.rose),
        const SizedBox(height: 12),
        Text(
          ErrorMessages.describe(error, context.l10n) + (code != null ? '\n($code)' : ''),
          key: const ValueKey('presupuestos-error'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: ref.read(limitsAdminNotifierProvider.notifier).cargarLimites,
            child: Text(context.l10n.retry),
          ),
        ),
      ]);
    }
    final lista = state.limitsFiltrados;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90).withBottomSafeArea(context),
      children: [
        _Resumen(state: state, principal: Currency.parse(ref.watch(settingsProvider.select((s) => s.defaultCurrency)))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('todos', '${context.l10n.all2} (${state.limits.length})'),
            const SizedBox(width: 8),
            chip('activos', '${context.l10n.current} (${state.activosCount})'),
            const SizedBox(width: 8),
            chip('vencidos', '${context.l10n.due} (${state.vencidosCount})'),
            const SizedBox(width: 8),
            chip('excedidos', '${context.l10n.exceeded} (${state.excedidosCount})'),
          ]),
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(context.l10n.noBudgets)),
          ),
        ...lista.map((b) => _BudgetCard(budget: b, onAction: (a) => _accion(context, b, a))),
      ],
    );
  }

  Future<void> _accion(BuildContext context, Budget b, String accion) async {
    final notifier = ref.read(limitsAdminNotifierProvider.notifier);
    switch (accion) {
      case 'edit':
        await _editar(context, b);
      case 'renew':
        final error = await notifier.run((r) => r.renew(b.id));
        if (context.mounted) await reportLocalAction(context, ref, error, ok: context.l10n.budgetRenewed);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.deleteBudget),
            content: Text(b.title),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.delete)),
            ],
          ),
        );
        if (ok != true) return;
        final error = await notifier.run((r) => r.delete(b.id));
        if (context.mounted) await reportLocalAction(context, ref, error, ok: context.l10n.budgetDeleted);
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String?> _pickDate(BuildContext context, String current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return picked == null ? null : _iso(picked);
  }

  /// Edición de fechas y monto (la sincronización no cambia categorías ni cuentas de un límite).
  Future<void> _editar(BuildContext context, Budget b) async {
    var desde = b.startDate, hasta = b.endDate;
    final montoTexto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [Money.toApiDecimal(b.limitCents).replaceAll('.', ',')],
        builder: (ctx, c) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(context.l10n.editBudget),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              _fecha(ctx, context.l10n.from, desde, (v) => setLocal(() => desde = v)),
              _fecha(ctx, context.l10n.to, hasta, (v) => setLocal(() => hasta = v)),
              TextField(
                key: const ValueKey('limite-monto'),
                controller: c[0],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: context.l10n.limit, prefixText: '${(b.currency ?? Currency.ars).symbol} '),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
              TextButton(
                  key: const ValueKey('limite-guardar'),
                  onPressed: () => Navigator.pop(ctx, c[0].text),
                  child: Text(context.l10n.save)),
            ],
          ),
        ),
      ),
    );
    if (montoTexto == null || !context.mounted) return;
    final cents = Money.parseInput(montoTexto);
    final error = cents == null
        ? LocalOps.invalid((l) => l.invalidAmountMax2Decimals)
        : await ref
            .read(limitsAdminNotifierProvider.notifier)
            .run((r) => r.update(b.id, startDate: desde, endDate: hasta, limitCents: cents));
    if (context.mounted) await reportLocalAction(context, ref, error, ok: context.l10n.budgetUpdated);
  }

  Widget _fecha(BuildContext ctx, String label, String value, ValueChanged<String> onChanged) => Row(children: [
        Expanded(child: Text(label)),
        TextButton(
          key: ValueKey('limite-$label'),
          onPressed: () async {
            final v = await _pickDate(ctx, value);
            if (v != null) onChanged(v);
          },
          child: Text(AppDateUtils.formatDateString(value)),
        ),
      ]);

  /// Alta: período (por defecto el mes en curso), monto, hasta 5 categorías y una o más cuentas.
  Future<void> _crear(BuildContext context) async {
    final catalog = await ref.read(localCatalogProvider);
    final categorias = await catalog.expenseCategories();
    final cuentas = await catalog.activeAccounts();
    if (!context.mounted) return;
    final hoy = LocalOps.todayAr();
    var desde = '${hoy.substring(0, 8)}01';
    var hasta = LocalBudgetsRepository.lastDayOfMonth(hoy);
    final cats = <int>{}, accs = <int>{};
    // Una sola moneda por límite: arranca en la principal y solo se ofrecen las cuentas de esa moneda.
    var moneda = Currency.parse(ref.read(settingsProvider).defaultCurrency);
    final montoTexto = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: const [''],
        builder: (ctx, c) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(context.l10n.newBudget),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fecha(ctx, context.l10n.from, desde, (v) => setLocal(() => desde = v)),
                _fecha(ctx, context.l10n.to, hasta, (v) => setLocal(() => hasta = v)),
                const SizedBox(height: 8),
                Text(context.l10n.budgetCurrency, style: const TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 6, children: [
                  for (final m in Currency.values)
                    ChoiceChip(
                      key: ValueKey('limite-moneda-${m.code}'),
                      label: Text(m.code),
                      selected: moneda == m,
                      onSelected: (_) => setLocal(() {
                        if (moneda != m) accs.clear();
                        moneda = m;
                      }),
                    ),
                ]),
                TextField(
                  key: const ValueKey('limite-monto'),
                  controller: c[0],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: context.l10n.limit, prefixText: '${moneda.symbol} '),
                ),
                const SizedBox(height: 10),
                Text('${context.l10n.categories2} (${cats.length}/$budgetMaxCategories)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 6, children: [
                  for (final c in categorias)
                    FilterChip(
                      key: ValueKey('limite-cat-${c.name}'),
                      label: Text(c.name),
                      selected: cats.contains(c.localId),
                      onSelected: (sel) =>
                          setLocal(() => sel && cats.length < budgetMaxCategories ? cats.add(c.localId) : cats.remove(c.localId)),
                    ),
                ]),
                const SizedBox(height: 10),
                Text(context.l10n.accounts2, style: const TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 6, children: [
                  for (final a in cuentas.where((a) => a.currency == moneda))
                    FilterChip(
                      key: ValueKey('limite-cuenta-${a.name}'),
                      label: Text(a.name.toUpperCase()),
                      selected: accs.contains(a.localId),
                      onSelected: (sel) => setLocal(() => sel ? accs.add(a.localId) : accs.remove(a.localId)),
                    ),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
              TextButton(
                  key: const ValueKey('limite-guardar'),
                  onPressed: () => Navigator.pop(ctx, c[0].text),
                  child: Text(context.l10n.save)),
            ],
          ),
        ),
      ),
    );
    if (montoTexto == null || !context.mounted) return;
    final cents = Money.parseInput(montoTexto);
    final error = cents == null
        ? LocalOps.invalid((l) => l.invalidAmountMax2Decimals)
        : await ref.read(limitsAdminNotifierProvider.notifier).run(
            (r) => r.create(startDate: desde, endDate: hasta, limitCents: cents, categoryIds: cats.toList(), accountIds: accs.toList()));
    if (context.mounted) await reportLocalAction(context, ref, error, ok: context.l10n.budgetCreated);
  }
}

class _Resumen extends StatelessWidget {
  final LimitsAdminState state;

  /// Moneda principal: su fila va primero. Una fila por moneda, sin conversión.
  final Currency principal;
  const _Resumen({required this.state, required this.principal});

  String _key(String base, Currency m) => m == principal ? base : '$base-${m.code}';

  @override
  Widget build(BuildContext context) {
    Widget col(String label, int cents, Currency moneda, Color color, String key) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  Text(Money.format(cents, currency: moneda), key: ValueKey(key), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.currentBudgets, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final m in [principal, ...Currency.values.where((c) => c != principal)])
            if (m == principal || state.monedasVigentes.contains(m))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  // La fila principal mantiene las claves de antes; las otras llevan la moneda.
                  col(context.l10n.limits, state.totalPresupuestadoCents(m), m, AppColors.primary, _key('total-topes', m)),
                  col(context.l10n.spent, state.totalConsumidoCents(m), m, AppColors.rose, _key('total-gastado', m)),
                  col(context.l10n.remaining, state.totalRestoCents(m), m,
                      state.totalRestoCents(m) < 0 ? AppColors.rose : AppColors.emerald, _key('total-restante', m)),
                ]),
              ),
        ]),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final ValueChanged<String> onAction;
  const _BudgetCard({required this.budget, required this.onAction});

  /// Umbrales de la web (F6.8): ≤25 info, <50 éxito, <90 advertencia, resto peligro.
  static Color colorFor(num? percent) {
    final p = percent ?? 0;
    if (p <= 25) return AppColors.primary;
    if (p < 50) return AppColors.emerald;
    if (p < 90) return AppColors.amber;
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final p = budget.percent;
    final color = colorFor(p);
    // Los que mezclan monedas (anteriores a la regla) siguen como antes, en pesos y con aviso.
    final moneda = budget.currency ?? Currency.ars;
    final progreso = p == null ? 0.0 : (p / 100).clamp(0.0, 1.0).toDouble();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(budget.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Text(p == null ? '—' : Money.percent(p),
                key: ValueKey('presupuesto-porcentaje-${budget.id}'), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            PopupMenuButton<String>(
              key: ValueKey('menu-limite-${budget.id}'),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
              ],
            ),
          ]),
          if (budget.currency == null)
            Text(context.l10n.mixedCurrencies,
                key: ValueKey('limite-mezcla-${budget.id}'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber)),
          Text(
            '${AppDateUtils.formatDateString(budget.startDate)} – ${AppDateUtils.formatDateString(budget.endDate)} · '
            '${budget.accounts.map((a) => a.name).join(', ')}',
            style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progreso, color: color, backgroundColor: color.withValues(alpha: 0.15), minHeight: 8),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                '${Money.format(budget.consumedCents, currency: moneda)} / ${Money.format(budget.limitCents, currency: moneda)}',
                key: ValueKey('presupuesto-consumo-${budget.id}'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              budget.exceeded
                  ? '${context.l10n.excess}: ${Money.format(-budget.remainingCents, currency: moneda)}'
                  : '${context.l10n.left}: ${Money.format(budget.remainingCents, currency: moneda)}',
              key: ValueKey('presupuesto-resto-${budget.id}'),
              style: TextStyle(fontSize: 12, color: budget.exceeded ? AppColors.rose : AppColors.emerald),
            ),
          ]),
          if (budget.dueForRenewal) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: ValueKey('renovar-${budget.id}'),
              onPressed: () => onAction('renew'),
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: Text(context.l10n.renew),
            ),
          ],
        ]),
      ),
    );
  }
}
