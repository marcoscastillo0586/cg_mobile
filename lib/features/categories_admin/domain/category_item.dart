import 'package:equatable/equatable.dart';

/// Rol de las categorías reservadas del sistema (`categories.role`).
enum CategoryRole {
  transfer('TRANSFER'),
  income('INCOME'),
  defaultTicket('DEFAULT_TICKET');

  final String code;
  const CategoryRole(this.code);

  static CategoryRole? parse(Object? value) {
    if (value == null) return null;
    for (final r in CategoryRole.values) {
      if (r.code == value) return r;
    }
    return null;
  }
}

/// Categoría (CategoryDto).
class CategoryItem extends Equatable {
  final int id;
  final String name;
  final bool active;

  /// No null = reservada: no se puede editar, borrar ni elegir en egresos/presupuestos
  /// (salvo DEFAULT_TICKET, que sí se elige en tickets).
  final CategoryRole? role;
  final int movementsCount;
  final int? version;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.active,
    required this.role,
    required this.movementsCount,
    this.version,
  });

  bool get isReserved => role != null;

  @override
  List<Object?> get props => [id, name, active, role, movementsCount, version];
}
