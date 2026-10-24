import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class QrTicketWarning extends Equatable {
  final String code;
  final String message;
  final int? itemIndex;
  const QrTicketWarning(this.code, this.message, this.itemIndex);

  @override
  List<Object?> get props => [code, message, itemIndex];
}

/// Renglón leído por el servidor desde el ticket digital (centavos).
class QrTicketItem extends Equatable {
  final String description;
  final String? plu;
  final int? unitPriceCents;

  /// Precio final del renglón (bruto − descuentos).
  final int netCents;

  /// Categoría sugerida por el servidor (id del SERVIDOR).
  final int? suggestedCategoryServerId;
  final bool doubtful;

  const QrTicketItem({
    required this.description,
    required this.plu,
    required this.unitPriceCents,
    required this.netCents,
    required this.suggestedCategoryServerId,
    required this.doubtful,
  });

  @override
  List<Object?> get props => [description, plu, unitPriceCents, netCents, suggestedCategoryServerId, doubtful];
}

/// Ticket digital leído con `POST /tickets/parse-url` (ParsedTicketDto).
class QrTicket extends Equatable {
  final String reader;
  final String sourceUrl;
  final String merchant;
  final String? branch;
  final String? cuit;
  final String? address;
  final String? receiptNumber;
  final String? receiptDate;

  /// aaaa-mm-dd si la fecha del ticket es válida.
  final String? isoDate;
  final String? receiptTime;
  final int? totalPrintedCents;
  final int itemsTotalCents;
  final List<QrTicketWarning> warnings;
  final List<QrTicketItem> items;

  const QrTicket({
    required this.reader,
    required this.sourceUrl,
    required this.merchant,
    this.branch,
    this.cuit,
    this.address,
    this.receiptNumber,
    this.receiptDate,
    this.isoDate,
    this.receiptTime,
    required this.totalPrintedCents,
    required this.itemsTotalCents,
    this.warnings = const [],
    required this.items,
  });

  /// Concepto general sugerido (como la web: comercio + sucursal).
  String get generalConcept {
    final c = [merchant, if (branch != null) branch!].where((s) => s.trim().isNotEmpty).join(' ');
    return c.length > 150 ? c.substring(0, 150) : c;
  }

  @override
  List<Object?> get props => [reader, sourceUrl, merchant, branch, cuit, address, receiptNumber, receiptDate, isoDate, receiptTime, totalPrintedCents, itemsTotalCents, warnings, items];
}

/// Renglón revisado para `POST /tickets/confirm` (ids del SERVIDOR, centavos).
class QrTicketConfirmItem {
  final String concept;
  final int categoryServerId;
  final int amountCents;
  final String? plu;
  final int? unitPriceCents;
  const QrTicketConfirmItem({required this.concept, required this.categoryServerId, required this.amountCents, this.plu, this.unitPriceCents});
}

class QrTicketConfirmation {
  final int accountServerId;
  final String date;
  final String generalConcept;
  final List<QrTicketConfirmItem> items;
  final QrTicket ticket;
  final String clientSyncId;

  const QrTicketConfirmation({
    required this.accountServerId,
    required this.date,
    required this.generalConcept,
    required this.items,
    required this.ticket,
    required this.clientSyncId,
  });

  Map<String, Object?> toJson() => {
        'accountId': accountServerId,
        'date': date,
        'generalConcept': generalConcept,
        'items': [
          for (final i in items)
            {
              'concept': i.concept,
              'categoryId': i.categoryServerId,
              'amount': Money.toApiDecimal(i.amountCents),
              'plu': i.plu,
              'unitPrice': i.unitPriceCents == null ? null : Money.toApiDecimal(i.unitPriceCents!),
            },
        ],
        'ticket': {
          'merchant': ticket.merchant,
          'branch': ticket.branch,
          'cuit': ticket.cuit,
          'address': ticket.address,
          'receiptNumber': ticket.receiptNumber,
          'receiptDate': ticket.receiptDate,
          'receiptTime': ticket.receiptTime,
          'totalReadCents': ticket.totalPrintedCents,
          'reader': ticket.reader.isEmpty ? 'desconocido' : ticket.reader,
          'sourceUrl': ticket.sourceUrl,
          'proposedItems': [
            for (final i in ticket.items)
              {'description': i.description, 'plu': i.plu, 'netCents': i.netCents, 'unitPriceCents': i.unitPriceCents, 'doubtful': i.doubtful},
          ],
          'warnings': [for (final w in ticket.warnings) {'code': w.code, 'message': w.message, if (w.itemIndex != null) 'itemIndex': w.itemIndex}],
        },
        'clientSyncId': clientSyncId,
      };
}
