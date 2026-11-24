import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/load_error_view.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/sync/reload_after_sync.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_utils.dart';
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
    reloadAfterSync(ref, () => ref.read(limitsAdminNotifierProvider.notifier).cargarLimites(silencioso: true));
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
      return LoadErrorView(error: error, onRetry: ref.read(limitsAdminNotifierProvider.notifier).cargarLimites);
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

  Future<void> _accion(BuildContext context, Budget b, String accion) => switch (accion) {
        'edit' => _editar(context, b),
        'renew' => _ejecutar(context, (r) => r.renew(b.id), context.l10n.budgetRenewed),
        _ => _eliminar(context, b),
      };

  Future<void> _ejecutar(BuildContext context, Future<Object?> Function(LocalBudgetsRepository r) accion, String ok) async {
    final error = await ref.read(limitsAdminNotifierProvider.notifier).run(accion);
    if (context.mounted) await reportLocalAction(context, ref, error, ok: ok);
  }

  /// Monto escrito por el usuario: inválido se avisa sin guardar nada.
  Future<void> _conMonto(BuildContext context, String texto, Future<Object?> Function(LocalBudgetsRepository r, int cents) accion, String ok) async {
    final cents = Money.parseInput(texto);
    if (cents != null) return _ejecutar(context, (r) => accion(r, cents), ok);
    await reportLocalAction(context, ref, LocalOps.invalid((l) => l.invalidAmountMax2Decimals), ok: ok);
  }

  Future<void> _eliminar(BuildContext context, Budget b) async {
    if (!await confirmar(context, title: context.l10n.deleteBudget, message: b.title, action: context.l10n.delete)) return;
    if (context.mounted) await _ejecutar(context, (r) => r.delete(b.id), context.l10n.budgetDeleted);
  }

  /// Edición de fechas y monto (la sincronización no cambia categorías ni cuentas de un límite).
  Future<void> _editar(BuildContext context, Budget b) async {
    final datos = await showDialog<_DatosLimite>(context: context, builder: (_) => _EditarLimiteDialog(budget: b));
    if (datos == null || !context.mounted) return;
    await _conMonto(context, datos.monto, (r, cents) => r.update(b.id, startDate: datos.desde, endDate: datos.hasta, limitCents: cents),
        context.l10n.budgetUpdated);
  }

  /// Alta: período (por defecto el mes en curso), monto, hasta 5 categorías y una o más cuentas.
  Future<void> _crear(BuildContext context) async {
    final catalog = await ref.read(localCatalogProvider);
    final categorias = await catalog.expenseCategories();
    final cuentas = await catalog.activeAccounts();
    if (!context.mounted) return;
    final principal = Currency.parse(ref.read(settingsProvider).defaultCurrency);
    final datos = await showDialog<_NuevoLimite>(
      context: context,
      builder: (_) => _NuevoLimiteDialog(categorias: categorias, cuentas: cuentas, monedaInicial: principal),
    );
    if (datos == null || !context.mounted) return;
    final (:limite, :cats, :accs) = datos;
    await _conMonto(
      context,
      limite.monto,
      (r, cents) => r.create(startDate: limite.desde, endDate: limite.hasta, limitCents: cents, categoryIds: cats, accountIds: accs),
      context.l10n.budgetCreated,
    );
  }
}

typedef _DatosLimite = ({String desde, String hasta, String monto});
typedef _NuevoLimite = ({_DatosLimite limite, List<int> cats, List<int> accs});

/// "Desde"/"Hasta" con selector de fecha (yyyy-MM-dd).
class _FechaFila extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _FechaFila({required this.label, required this.value, required this.onChanged});

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _elegir(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(value) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(_iso(picked));
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        TextButton(key: ValueKey('limite-$label'), onPressed: () => _elegir(context), child: Text(AppDateUtils.formatDateString(value))),
      ]);
}

/// Fechas y monto de un límite, con su controlador de texto.
abstract class _LimiteDialogState<T extends StatefulWidget> extends State<T> {
  late String desde;
  late String hasta;
  late final TextEditingController monto;

  @override
  void dispose() {
    monto.dispose();
    super.dispose();
  }

  _DatosLimite get datos => (desde: desde, hasta: hasta, monto: monto.text);

  List<Widget> fechas(BuildContext context) => [
        _FechaFila(label: context.l10n.from, value: desde, onChanged: (v) => setState(() => desde = v)),
        _FechaFila(label: context.l10n.to, value: hasta, onChanged: (v) => setState(() => hasta = v)),
      ];

  Widget campoMonto(BuildContext context, Currency moneda) => TextField(
        key: const ValueKey('limite-monto'),
        controller: monto,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: context.l10n.limit, prefixText: '${moneda.symbol} '),
      );

  Widget dialogo(BuildContext context, {required String titulo, required List<Widget> contenido, required Object Function() resultado}) =>
      AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          TextButton(key: const ValueKey('limite-guardar'), onPressed: () => Navigator.pop(context, resultado()), child: Text(context.l10n.save)),
        ],
      );
}

class _EditarLimiteDialog extends StatefulWidget {
  final Budget budget;
  const _EditarLimiteDialog({required this.budget});

  @override
  State<_EditarLimiteDialog> createState() => _EditarLimiteDialogState();
}

class _EditarLimiteDialogState extends _LimiteDialogState<_EditarLimiteDialog> {
  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    desde = b.startDate;
    hasta = b.endDate;
    monto = TextEditingController(text: Money.toApiDecimal(b.limitCents).replaceAll('.', ','));
  }

  @override
  Widget build(BuildContext context) => dialogo(
        context,
        titulo: context.l10n.editBudget,
        contenido: [
          Text(widget.budget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ...fechas(context),
          campoMonto(context, widget.budget.currency ?? Currency.ars),
        ],
        resultado: () => datos,
      );
}

class _NuevoLimiteDialog extends StatefulWidget {
  final List<LocalCategory> categorias;
  final List<LocalAccount> cuentas;
  final Currency monedaInicial;
  const _NuevoLimiteDialog({required this.categorias, required this.cuentas, required this.monedaInicial});

  @override
  State<_NuevoLimiteDialog> createState() => _NuevoLimiteDialogState();
}

class _NuevoLimiteDialogState extends _LimiteDialogState<_NuevoLimiteDialog> {
  final _cats = <int>{};
  final _accs = <int>{};

  /// Una sola moneda por límite: arranca en la principal y solo se ofrecen las cuentas de esa moneda.
  late var _moneda = widget.monedaInicial;

  @override
  void initState() {
    super.initState();
    final hoy = LocalOps.todayAr();
    desde = '${hoy.substring(0, 8)}01';
    hasta = LocalBudgetsRepository.lastDayOfMonth(hoy);
    monto = TextEditingController();
  }

  void _elegirMoneda(Currency m) => setState(() {
        if (_moneda != m) _accs.clear();
        _moneda = m;
      });

  void _elegirCategoria(int id, bool sel) => setState(() => sel && _cats.length < budgetMaxCategories ? _cats.add(id) : _cats.remove(id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const negrita = TextStyle(fontWeight: FontWeight.w600);
    return dialogo(
      context,
      titulo: l10n.newBudget,
      contenido: [
        ...fechas(context),
        const SizedBox(height: 8),
        Text(l10n.budgetCurrency, style: negrita),
        Wrap(spacing: 6, children: [
          for (final m in Currency.values)
            ChoiceChip(key: ValueKey('limite-moneda-${m.code}'), label: Text(m.code), selected: _moneda == m, onSelected: (_) => _elegirMoneda(m)),
        ]),
        campoMonto(context, _moneda),
        const SizedBox(height: 10),
        Text('${l10n.categories2} (${_cats.length}/$budgetMaxCategories)', style: negrita),
        Wrap(spacing: 6, children: [
          for (final c in widget.categorias)
            FilterChip(
              key: ValueKey('limite-cat-${c.name}'),
              label: Text(c.name),
              selected: _cats.contains(c.localId),
              onSelected: (sel) => _elegirCategoria(c.localId, sel),
            ),
        ]),
        const SizedBox(height: 10),
        Text(l10n.accounts2, style: negrita),
        Wrap(spacing: 6, children: [
          for (final a in widget.cuentas.where((a) => a.currency == _moneda))
            FilterChip(
              key: ValueKey('limite-cuenta-${a.name}'),
              label: Text(a.name.toUpperCase()),
              selected: _accs.contains(a.localId),
              onSelected: (sel) => setState(() => sel ? _accs.add(a.localId) : _accs.remove(a.localId)),
            ),
        ]),
      ],
      resultado: () => (limite: datos, cats: _cats.toList(), accs: _accs.toList()),
    );
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
