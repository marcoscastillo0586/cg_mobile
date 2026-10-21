import 'package:equatable/equatable.dart';
import '../../../dashboard/domain/entities/account_entity.dart';

enum TransferFormStatus { initial, loading, ready, submitting, success, error }

class TransferFormState extends Equatable {
  final TransferFormStatus status;
  final List<AccountEntity> lugares;
  final int? selectedOrigenId;
  final int? selectedDestinoId;
  final double monto;
  final String concepto;
  final DateTime fecha;
  final String? errorMessage;

  const TransferFormState({
    required this.status,
    this.lugares = const [],
    this.selectedOrigenId,
    this.selectedDestinoId,
    this.monto = 0.0,
    this.concepto = '',
    required this.fecha,
    this.errorMessage,
  });

  factory TransferFormState.initial() => TransferFormState(
        status: TransferFormStatus.initial,
        fecha: DateTime.now(),
      );

  TransferFormState copyWith({
    TransferFormStatus? status,
    List<AccountEntity>? lugares,
    int? selectedOrigenId,
    int? selectedDestinoId,
    double? monto,
    String? concepto,
    DateTime? fecha,
    String? errorMessage,
  }) {
    return TransferFormState(
      status: status ?? this.status,
      lugares: lugares ?? this.lugares,
      selectedOrigenId: selectedOrigenId ?? this.selectedOrigenId,
      selectedDestinoId: selectedDestinoId ?? this.selectedDestinoId,
      monto: monto ?? this.monto,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isSubmitting => status == TransferFormStatus.submitting;

  @override
  List<Object?> get props => [
        status,
        lugares,
        selectedOrigenId,
        selectedDestinoId,
        monto,
        concepto,
        fecha,
        errorMessage,
      ];
}
