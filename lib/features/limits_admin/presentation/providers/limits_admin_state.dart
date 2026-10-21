import 'package:equatable/equatable.dart';
import '../../domain/entities/expense_limit_admin_entity.dart';

enum LimitsAdminStatus { initial, loading, loaded, error }

class LimitsAdminState extends Equatable {
  final LimitsAdminStatus status;
  final List<ExpenseLimitAdminEntity> limits;
  final String filtroEstado; // 'todos', 'activos', 'vencidos', 'excedidos'
  final bool isSaving;
  final bool isRenewing;
  final bool isDeleting;
  final String? errorMessage;
  final String? successMessage;

  const LimitsAdminState({
    required this.status,
    required this.limits,
    required this.filtroEstado,
    required this.isSaving,
    required this.isRenewing,
    required this.isDeleting,
    this.errorMessage,
    this.successMessage,
  });

  factory LimitsAdminState.initial() {
    return const LimitsAdminState(
      status: LimitsAdminStatus.initial,
      limits: [],
      filtroEstado: 'todos',
      isSaving: false,
      isRenewing: false,
      isDeleting: false,
    );
  }

  List<ExpenseLimitAdminEntity> get limitsFiltrados {
    var list = limits;

    // Filtro por estado
    if (filtroEstado == 'activos') {
      list = list.where((l) => !l.vencido).toList();
    } else if (filtroEstado == 'vencidos') {
      list = list.where((l) => l.vencido).toList();
    } else if (filtroEstado == 'excedidos') {
      list = list.where((l) => l.excedido).toList();
    }

    return list;
  }

  // Totales para métricas globales
  double get totalPresupuestado => limits
      .where((l) => !l.vencido)
      .fold(0.0, (acc, l) => acc + l.montoLimite);

  double get totalConsumido => limits
      .where((l) => !l.vencido)
      .fold(0.0, (acc, l) => acc + l.montoConsumido);

  double get totalResto => totalPresupuestado - totalConsumido;

  double get porcentajeGlobal => totalPresupuestado > 0
      ? ((totalConsumido / totalPresupuestado) * 100).clamp(0.0, 999.0)
      : 0.0;

  int get activosCount => limits.where((l) => !l.vencido).length;
  int get vencidosCount => limits.where((l) => l.vencido).length;
  int get excedidosCount => limits.where((l) => l.excedido).length;

  LimitsAdminState copyWith({
    LimitsAdminStatus? status,
    List<ExpenseLimitAdminEntity>? limits,
    String? filtroEstado,
    bool? isSaving,
    bool? isRenewing,
    bool? isDeleting,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return LimitsAdminState(
      status: status ?? this.status,
      limits: limits ?? this.limits,
      filtroEstado: filtroEstado ?? this.filtroEstado,
      isSaving: isSaving ?? this.isSaving,
      isRenewing: isRenewing ?? this.isRenewing,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        limits,
        filtroEstado,
        isSaving,
        isRenewing,
        isDeleting,
        errorMessage,
        successMessage,
      ];
}
