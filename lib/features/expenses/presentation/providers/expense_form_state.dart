import 'package:equatable/equatable.dart';
import '../../domain/entities/expense_form_data_entity.dart';
import '../../domain/entities/renglon_gasto.dart';
import '../../domain/entities/ticket_parse_result.dart';

enum ExpenseFormStatus {
  initial,
  loadingData,
  ready,
  submitting,
  success,
  error,
}

class ExpenseFormState extends Equatable {
  final ExpenseFormStatus status;
  final ExpenseFormDataEntity? formData;
  final int? selectedLugarId;
  final DateTime fecha;
  final String conceptoGeneral;
  final List<RenglonGasto> renglones;
  final int? editingId;
  final TicketParseResult? ticketParseResult;
  final String? errorMessage;
  final String? qrFeedback;

  const ExpenseFormState({
    required this.status,
    this.formData,
    this.selectedLugarId,
    required this.fecha,
    this.conceptoGeneral = '',
    this.renglones = const [],
    this.editingId,
    this.ticketParseResult,
    this.errorMessage,
    this.qrFeedback,
  });

  factory ExpenseFormState.initial() => ExpenseFormState(
        status: ExpenseFormStatus.initial,
        fecha: DateTime.now(),
        renglones: [RenglonGasto.nuevo()],
      );

  ExpenseFormState copyWith({
    ExpenseFormStatus? status,
    ExpenseFormDataEntity? formData,
    int? selectedLugarId,
    DateTime? fecha,
    String? conceptoGeneral,
    List<RenglonGasto>? renglones,
    int? editingId,
    TicketParseResult? ticketParseResult,
    String? errorMessage,
    String? qrFeedback,
  }) {
    return ExpenseFormState(
      status: status ?? this.status,
      formData: formData ?? this.formData,
      selectedLugarId: selectedLugarId ?? this.selectedLugarId,
      fecha: fecha ?? this.fecha,
      conceptoGeneral: conceptoGeneral ?? this.conceptoGeneral,
      renglones: renglones ?? this.renglones,
      editingId: editingId ?? this.editingId,
      ticketParseResult: ticketParseResult ?? this.ticketParseResult,
      errorMessage: errorMessage ?? this.errorMessage,
      qrFeedback: qrFeedback ?? this.qrFeedback,
    );
  }

  bool get isEditing => editingId != null;
  bool get isSubmitting => status == ExpenseFormStatus.submitting;
  bool get isLoadingData => status == ExpenseFormStatus.loadingData;

  /// Monto total calculado automáticamente (suma reactiva de cada renglón)
  double get totalCalculado => renglones.fold(0.0, (acc, r) => acc + r.monto);

  /// Cantidad actual de renglones cargados
  int get cantidadRenglones => renglones.length;

  /// Solo permite eliminar si hay más de 1 renglón
  bool get puedeEliminarRenglon => renglones.length > 1;

  /// Validación de completitud para el botón dinámico (Punto 6.8)
  bool get isFormComplete {
    if (selectedLugarId == null) return false;
    if (conceptoGeneral.trim().isEmpty) return false;
    if (renglones.isEmpty) return false;
    for (final r in renglones) {
      if (r.monto <= 0) return false;
      if (r.categoriaId == null || r.categoriaId! <= 0) return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [
        status,
        formData,
        selectedLugarId,
        fecha,
        conceptoGeneral,
        renglones,
        editingId,
        ticketParseResult,
        errorMessage,
        qrFeedback,
      ];
}
