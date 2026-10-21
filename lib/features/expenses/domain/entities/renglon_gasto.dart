import 'package:equatable/equatable.dart';
import 'category_entity.dart';
import 'expense_item_entity.dart';

/// Modelo de entidad que representa un renglón individual dentro de un gasto dinámico.
class RenglonGasto extends Equatable {
  final String id;
  final String concepto;
  final double monto;
  final int? categoriaId;
  final CategoryEntity? categoria;

  const RenglonGasto({
    required this.id,
    this.concepto = '',
    this.monto = 0.0,
    this.categoriaId,
    this.categoria,
  });

  static int _idCounter = 0;

  /// Crea un nuevo renglón con un ID temporal único garantizado
  factory RenglonGasto.nuevo({
    int? defaultCategoriaId,
    CategoryEntity? defaultCategoria,
  }) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _idCounter++;
    return RenglonGasto(
      id: 'renglon_${timestamp}_$_idCounter',
      concepto: '',
      monto: 0.0,
      categoriaId: defaultCategoriaId,
      categoria: defaultCategoria,
    );
  }

  RenglonGasto copyWith({
    String? id,
    String? concepto,
    double? monto,
    int? categoriaId,
    CategoryEntity? categoria,
  }) {
    return RenglonGasto(
      id: id ?? this.id,
      concepto: concepto ?? this.concepto,
      monto: monto ?? this.monto,
      categoriaId: categoriaId ?? this.categoriaId,
      categoria: categoria ?? this.categoria,
    );
  }

  /// Convierte el renglón a la entidad DTO que consume el repositorio/API
  ExpenseItemEntity toExpenseItemEntity({String fallbackConcepto = 'Gasto'}) {
    return ExpenseItemEntity(
      monto: monto,
      idCategoria: categoriaId ?? categoria?.idCategoria ?? 3,
      concepto: concepto.trim().isEmpty ? fallbackConcepto : concepto.trim(),
    );
  }

  @override
  List<Object?> get props => [id, concepto, monto, categoriaId, categoria];
}
