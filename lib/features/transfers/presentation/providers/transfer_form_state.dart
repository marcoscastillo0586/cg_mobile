import 'package:equatable/equatable.dart';
import '../../../../core/database/local_catalog.dart';

enum TransferFormStatus { initial, loading, ready, submitting, success, error }

class TransferFormState extends Equatable {
  final TransferFormStatus status;
  final List<LocalAccount> cuentas;

  /// Ids locales de origen y destino.
  final int? selectedOrigenId;
  final int? selectedDestinoId;
  final int montoCents;
  final String concepto;
  final DateTime fecha;
  final Object? error;

  const TransferFormState({
    required this.status,
    this.cuentas = const [],
    this.selectedOrigenId,
    this.selectedDestinoId,
    this.montoCents = 0,
    this.concepto = '',
    required this.fecha,
    this.error,
  });

  factory TransferFormState.initial() => TransferFormState(status: TransferFormStatus.initial, fecha: DateTime.now());

  TransferFormState copyWith({
    TransferFormStatus? status,
    List<LocalAccount>? cuentas,
    int? selectedOrigenId,
    int? selectedDestinoId,
    bool clearDestino = false,
    int? montoCents,
    String? concepto,
    DateTime? fecha,
    Object? error,
    bool clearError = false,
  }) {
    return TransferFormState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      selectedOrigenId: selectedOrigenId ?? this.selectedOrigenId,
      selectedDestinoId: clearDestino ? null : (selectedDestinoId ?? this.selectedDestinoId),
      montoCents: montoCents ?? this.montoCents,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isSubmitting => status == TransferFormStatus.submitting;

  LocalAccount? _byId(int? id) {
    for (final c in cuentas) {
      if (c.localId == id) return c;
    }
    return null;
  }

  LocalAccount? get origen => _byId(selectedOrigenId);
  LocalAccount? get destino => _byId(selectedDestinoId);

  /// Solo cuentas de la misma moneda que el origen (CURRENCY_MISMATCH en el servidor).
  List<LocalAccount> get destinosValidos {
    final o = origen;
    return cuentas.where((c) => o == null || (c.localId != o.localId && c.currency == o.currency)).toList();
  }

  /// Aviso previo: el monto supera el saldo local del origen.
  bool get fondosInsuficientes {
    final o = origen;
    return o != null && montoCents > o.balanceCents;
  }

  @override
  List<Object?> get props => [status, cuentas, selectedOrigenId, selectedDestinoId, montoCents, concepto, fecha, error];
}
