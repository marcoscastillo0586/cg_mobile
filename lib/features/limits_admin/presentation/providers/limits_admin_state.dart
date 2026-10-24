import 'package:equatable/equatable.dart';
import '../../domain/budget.dart';

enum LimitsAdminStatus { initial, loading, loaded, error }

class LimitsAdminState extends Equatable {
  final LimitsAdminStatus status;
  final List<Budget> limits;
  final String filtroEstado; // 'todos', 'activos', 'vencidos', 'excedidos'
  final Object? error;

  const LimitsAdminState({
    required this.status,
    required this.limits,
    required this.filtroEstado,
    this.error,
  });

  factory LimitsAdminState.initial() =>
      const LimitsAdminState(status: LimitsAdminStatus.initial, limits: [], filtroEstado: 'todos');

  /// Orden de la web (F6.8): por nombre de categoría.
  List<Budget> get limitsFiltrados {
    var list = [...limits]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (filtroEstado == 'activos') list = list.where((l) => !l.dueForRenewal).toList();
    if (filtroEstado == 'vencidos') list = list.where((l) => l.dueForRenewal).toList();
    if (filtroEstado == 'excedidos') list = list.where((l) => l.exceeded).toList();
    return list;
  }

  Iterable<Budget> get _vigentes => limits.where((l) => !l.dueForRenewal);

  /// Totales de los presupuestos vigentes (centavos).
  int get totalPresupuestadoCents => _vigentes.fold(0, (a, l) => a + l.limitCents);
  int get totalConsumidoCents => _vigentes.fold(0, (a, l) => a + l.consumedCents);
  int get totalRestoCents => _vigentes.fold(0, (a, l) => a + l.remainingCents);

  int get activosCount => _vigentes.length;
  int get vencidosCount => limits.where((l) => l.dueForRenewal).length;
  int get excedidosCount => limits.where((l) => l.exceeded).length;

  LimitsAdminState copyWith({
    LimitsAdminStatus? status,
    List<Budget>? limits,
    String? filtroEstado,
    Object? error,
    bool clearError = false,
  }) {
    return LimitsAdminState(
      status: status ?? this.status,
      limits: limits ?? this.limits,
      filtroEstado: filtroEstado ?? this.filtroEstado,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, limits, filtroEstado, error];
}
