import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/movement_item.dart';
import '../../../../l10n/l10n.dart';

/// Comprobante con sus renglones desplegables (F7.3).
class MovementCard extends StatelessWidget {
  final MovementItem item;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  /// Solo quien lo cargó lo edita o lo borra.
  final bool canEdit;

  const MovementCard({
    super.key,
    required this.item,
    required this.onEditar,
    required this.onEliminar,
    this.canEdit = true,
  });

  (IconData, Color, String) _tipo(AppLocalizations l) => switch (item.type) {
        MovementType.income => (Icons.arrow_downward_rounded, AppColors.emerald, l.income),
        MovementType.expense => (Icons.arrow_upward_rounded, AppColors.rose, l.expense),
        MovementType.transfer => (Icons.swap_horiz_rounded, AppColors.primary, l.transfer),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _tipo(context.l10n);
    final concepto = (item.generalConcept ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey('mov-${item.id}'),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 20)),
        title: Text(
          concepto.isEmpty ? label : concepto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppDateUtils.formatDateTimeString(item.occurredAt)} · ${item.accountNames.join(' → ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if ((item.createdByName ?? '').isNotEmpty)
              Text(
                context.l10n.movementCreatedBy(item.createdByName!),
                key: ValueKey('mov-autor-${item.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
              ),
          ],
        ),
        trailing: Text(
          Money.format(item.amountCents, currency: item.currency),
          key: ValueKey('mov-importe-${item.id}'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: item.type == MovementType.transfer ? AppColors.primary : (item.amountCents < 0 ? AppColors.rose : AppColors.emerald),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          ...item.details.map((d) => _DetailRow(detail: d)),
          if (item.partialDetails)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.showingLinesFilter(item.details.length, item.detailsCount),
                style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
              ),
            ),
          if (canEdit)
            Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(onPressed: onEditar, icon: const Icon(Icons.edit_outlined, size: 18), label: Text(context.l10n.edit)),
              TextButton.icon(
                onPressed: onEliminar,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                label: Text(context.l10n.delete, style: const TextStyle(color: AppColors.rose)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final MovementDetailItem detail;
  const _DetailRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final extra = [
      if (detail.categoryName != null) detail.categoryName!,
      detail.accountName,
      if (detail.plu != null) 'PLU ${detail.plu}',
      if (detail.unitPriceCents != null) '${context.l10n.unit} ${Money.format(detail.unitPriceCents!, currency: detail.currency)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(detail.concept ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(extra, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
            ]),
          ),
          Text(
            Money.format(detail.amountCents, currency: detail.currency),
            key: ValueKey('mov-renglon-${detail.id}'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
