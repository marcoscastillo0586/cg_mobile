import 'package:equatable/equatable.dart';
import '../../../../core/database/local_catalog.dart';

enum IncomeFormStatus { initial, loading, ready, submitting, success, error }

class IncomeFormState extends Equatable {
  final IncomeFormStatus status;
  final List<LocalAccount> cuentas;

  /// Id local de la cuenta de destino.
  final int? selectedCuentaId;
  final int montoCents;
  final String concepto;
  final DateTime fecha;

  /// Último error (se traduce en la pantalla).
  final Object? error;

  const IncomeFormState({
    required this.status,
    this.cuentas = const [],
    this.selectedCuentaId,
    this.montoCents = 0,
    this.concepto = '',
    required this.fecha,
    this.error,
  });

  factory IncomeFormState.initial() => IncomeFormState(status: IncomeFormStatus.initial, fecha: DateTime.now());

  IncomeFormState copyWith({
    IncomeFormStatus? status,
    List<LocalAccount>? cuentas,
    int? selectedCuentaId,
    int? montoCents,
    String? concepto,
    DateTime? fecha,
    Object? error,
    bool clearError = false,
  }) {
    return IncomeFormState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      selectedCuentaId: selectedCuentaId ?? this.selectedCuentaId,
      montoCents: montoCents ?? this.montoCents,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isSubmitting => status == IncomeFormStatus.submitting;

  LocalAccount? get cuentaSeleccionada {
    for (final c in cuentas) {
      if (c.localId == selectedCuentaId) return c;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, cuentas, selectedCuentaId, montoCents, concepto, fecha, error];
}
