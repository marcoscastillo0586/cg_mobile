import 'package:equatable/equatable.dart';
import '../../../dashboard/domain/entities/account_entity.dart';

enum IncomeFormStatus { initial, loading, ready, submitting, success, error }

class IncomeFormState extends Equatable {
  final IncomeFormStatus status;
  final List<AccountEntity> lugares;
  final int? selectedLugarId;
  final double monto;
  final String concepto;
  final DateTime fecha;
  final String? errorMessage;

  const IncomeFormState({
    required this.status,
    this.lugares = const [],
    this.selectedLugarId,
    this.monto = 0.0,
    this.concepto = '',
    required this.fecha,
    this.errorMessage,
  });

  factory IncomeFormState.initial() => IncomeFormState(
        status: IncomeFormStatus.initial,
        fecha: DateTime.now(),
      );

  IncomeFormState copyWith({
    IncomeFormStatus? status,
    List<AccountEntity>? lugares,
    int? selectedLugarId,
    double? monto,
    String? concepto,
    DateTime? fecha,
    String? errorMessage,
  }) {
    return IncomeFormState(
      status: status ?? this.status,
      lugares: lugares ?? this.lugares,
      selectedLugarId: selectedLugarId ?? this.selectedLugarId,
      monto: monto ?? this.monto,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isSubmitting => status == IncomeFormStatus.submitting;

  @override
  List<Object?> get props => [
        status,
        lugares,
        selectedLugarId,
        monto,
        concepto,
        fecha,
        errorMessage,
      ];
}
