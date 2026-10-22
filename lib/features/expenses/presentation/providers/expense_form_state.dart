import 'package:equatable/equatable.dart';
import '../../../../core/database/local_catalog.dart';
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
  final List<LocalAccount> cuentas;
  final List<LocalCategory> categorias;
  final List<String> conceptos;

  /// Id local de la cuenta elegida.
  final int? selectedCuentaId;
  final DateTime fecha;
  final String conceptoGeneral;
  final List<RenglonGasto> renglones;
  final TicketParseResult? ticketParseResult;

  /// Último error (se traduce en la pantalla con ErrorMessages).
  final Object? error;
  final String? qrFeedback;

  const ExpenseFormState({
    required this.status,
    this.cuentas = const [],
    this.categorias = const [],
    this.conceptos = const [],
    this.selectedCuentaId,
    required this.fecha,
    this.conceptoGeneral = '',
    this.renglones = const [],
    this.ticketParseResult,
    this.error,
    this.qrFeedback,
  });

  factory ExpenseFormState.initial() => ExpenseFormState(
        status: ExpenseFormStatus.initial,
        fecha: DateTime.now(),
        renglones: [RenglonGasto.nuevo()],
      );

  ExpenseFormState copyWith({
    ExpenseFormStatus? status,
    List<LocalAccount>? cuentas,
    List<LocalCategory>? categorias,
    List<String>? conceptos,
    int? selectedCuentaId,
    DateTime? fecha,
    String? conceptoGeneral,
    List<RenglonGasto>? renglones,
    TicketParseResult? ticketParseResult,
    bool clearTicket = false,
    Object? error,
    bool clearError = false,
    String? qrFeedback,
  }) {
    return ExpenseFormState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      categorias: categorias ?? this.categorias,
      conceptos: conceptos ?? this.conceptos,
      selectedCuentaId: selectedCuentaId ?? this.selectedCuentaId,
      fecha: fecha ?? this.fecha,
      conceptoGeneral: conceptoGeneral ?? this.conceptoGeneral,
      renglones: renglones ?? this.renglones,
      ticketParseResult: clearTicket ? null : (ticketParseResult ?? this.ticketParseResult),
      error: clearError ? null : (error ?? this.error),
      qrFeedback: clearTicket ? null : (qrFeedback ?? this.qrFeedback),
    );
  }

  bool get isSubmitting => status == ExpenseFormStatus.submitting;
  bool get isLoadingData => status == ExpenseFormStatus.loadingData;

  /// Total en centavos (suma de los renglones).
  int get totalCents => renglones.fold(0, (acc, r) => acc + r.montoCents);

  int get cantidadRenglones => renglones.length;

  bool get puedeEliminarRenglon => renglones.length > 1;

  LocalAccount? get cuentaSeleccionada {
    for (final c in cuentas) {
      if (c.localId == selectedCuentaId) return c;
    }
    return null;
  }

  /// Aviso previo: el total supera el saldo local de la cuenta (que ya descuenta lo pendiente).
  bool get fondosInsuficientes {
    final c = cuentaSeleccionada;
    return c != null && totalCents > c.balanceCents;
  }

  /// Validación de completitud para el botón dinámico (Punto 6.8)
  bool get isFormComplete {
    if (selectedCuentaId == null) return false;
    if (conceptoGeneral.trim().isEmpty) return false;
    if (renglones.isEmpty) return false;
    for (final r in renglones) {
      if (r.montoCents <= 0) return false;
      if (r.categoriaId == null) return false;
    }
    return !fondosInsuficientes;
  }

  @override
  List<Object?> get props => [
        status,
        cuentas,
        categorias,
        conceptos,
        selectedCuentaId,
        fecha,
        conceptoGeneral,
        renglones,
        ticketParseResult,
        error,
        qrFeedback,
      ];
}
