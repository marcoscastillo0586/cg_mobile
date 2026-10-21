import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/budget.dart';
import '../providers/limits_admin_notifier.dart';
import '../providers/limits_admin_state.dart';

class LimitsAdminScreen extends ConsumerStatefulWidget {
  const LimitsAdminScreen({super.key});

  @override
  ConsumerState<LimitsAdminScreen> createState() => _LimitsAdminScreenState();
}

class _LimitsAdminScreenState extends ConsumerState<LimitsAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(limitsAdminNotifierProvider.notifier).cargarLimites());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(limitsAdminNotifierProvider);
    final isEn = ref.watch(settingsProvider).language == 'en';
    final notifier = ref.read(limitsAdminNotifierProvider.notifier);

    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: state.filtroEstado == key,
          onSelected: (_) => notifier.setFiltroEstado(key),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Budgets' : 'Límites y Presupuestos'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: notifier.cargarLimites)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNotAvailable(context, isEn: isEn),
        icon: const Icon(Icons.add_rounded),
        label: Text(isEn ? 'New budget' : 'Nuevo límite'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.cargarLimites,
        child: _body(state, isEn, chip),
      ),
    );
  }

  Widget _body(LimitsAdminState state, bool isEn, Widget Function(String, String) chip) {
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
          ErrorMessages.describe(error, isEn: isEn) + (code != null ? '\n($code)' : ''),
          key: const ValueKey('presupuestos-error'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: ref.read(limitsAdminNotifierProvider.notifier).cargarLimites,
            child: Text(isEn ? 'Retry' : 'Reintentar'),
          ),
        ),
      ]);
    }
    final lista = state.limitsFiltrados;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _Resumen(state: state, isEn: isEn),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('todos', '${isEn ? 'All' : 'Todos'} (${state.limits.length})'),
            const SizedBox(width: 8),
            chip('activos', '${isEn ? 'Current' : 'En curso'} (${state.activosCount})'),
            const SizedBox(width: 8),
            chip('vencidos', '${isEn ? 'Due' : 'Vencidos'} (${state.vencidosCount})'),
            const SizedBox(width: 8),
            chip('excedidos', '${isEn ? 'Exceeded' : 'Excedidos'} (${state.excedidosCount})'),
          ]),
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(isEn ? 'No budgets' : 'No hay presupuestos')),
          ),
        ...lista.map((b) => _BudgetCard(budget: b, isEn: isEn)),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  final LimitsAdminState state;
  final bool isEn;
  const _Resumen({required this.state, required this.isEn});

  @override
  Widget build(BuildContext context) {
    Widget col(String label, int cents, Color color, String key) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Money.format(cents),
                  key: ValueKey(key), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEn ? 'Current budgets' : 'Presupuestos vigentes',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            col(isEn ? 'Limits' : 'Total topes', state.totalPresupuestadoCents, AppColors.primary, 'total-topes'),
            col(isEn ? 'Spent' : 'Gastado', state.totalConsumidoCents, AppColors.rose, 'total-gastado'),
            col(isEn ? 'Remaining' : 'Restante', state.totalRestoCents,
                state.totalRestoCents < 0 ? AppColors.rose : AppColors.emerald, 'total-restante'),
          ]),
        ]),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final bool isEn;
  const _BudgetCard({required this.budget, required this.isEn});

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
    final progreso = p == null ? 0.0 : (p / 100).clamp(0.0, 1.0).toDouble();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(budget.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(p == null ? '—' : Money.percent(p),
                key: ValueKey('presupuesto-porcentaje-${budget.id}'),
                style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            PopupMenuButton<String>(
              onSelected: (_) => showNotAvailable(context, isEn: isEn),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(isEn ? 'Edit' : 'Editar')),
                PopupMenuItem(value: 'delete', child: Text(isEn ? 'Delete' : 'Eliminar')),
              ],
            ),
          ]),
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
                '${Money.format(budget.consumedCents)} / ${Money.format(budget.limitCents)}',
                key: ValueKey('presupuesto-consumo-${budget.id}'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              budget.exceeded
                  ? '${isEn ? 'Excess' : 'Excedente'}: ${Money.format(-budget.remainingCents)}'
                  : '${isEn ? 'Left' : 'Resta'}: ${Money.format(budget.remainingCents)}',
              key: ValueKey('presupuesto-resto-${budget.id}'),
              style: TextStyle(fontSize: 12, color: budget.exceeded ? AppColors.rose : AppColors.emerald),
            ),
          ]),
          if (budget.dueForRenewal) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showNotAvailable(context, isEn: isEn),
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: Text(isEn ? 'Renew' : 'Renovar'),
            ),
          ],
        ]),
      ),
    );
  }
}
