import 'package:equatable/equatable.dart';

/// Renglón del formulario de egreso. Importe en centavos (entero); categoría por id local.
class RenglonGasto extends Equatable {
  final String id;
  final String concepto;
  final int montoCents;
  final int? categoriaId;

  /// Solo renglones de un ticket QR: se envían en /tickets/confirm.
  final String? plu;
  final int? unitPriceCents;

  const RenglonGasto({
    required this.id,
    this.concepto = '',
    this.montoCents = 0,
    this.categoriaId,
    this.plu,
    this.unitPriceCents,
  });

  static int _idCounter = 0;

  /// Crea un nuevo renglón con un ID temporal único garantizado
  factory RenglonGasto.nuevo({int? defaultCategoriaId}) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _idCounter++;
    return RenglonGasto(id: 'renglon_${timestamp}_$_idCounter', categoriaId: defaultCategoriaId);
  }

  RenglonGasto copyWith({String? concepto, int? montoCents, int? categoriaId, String? plu, int? unitPriceCents}) => RenglonGasto(
        id: id,
        concepto: concepto ?? this.concepto,
        montoCents: montoCents ?? this.montoCents,
        categoriaId: categoriaId ?? this.categoriaId,
        plu: plu ?? this.plu,
        unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      );

  @override
  List<Object?> get props => [id, concepto, montoCents, categoriaId, plu, unitPriceCents];
}
