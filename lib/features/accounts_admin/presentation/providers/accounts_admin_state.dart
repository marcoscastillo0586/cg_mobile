import 'package:equatable/equatable.dart';
import '../../domain/account_item.dart';

enum AccountsAdminStatus { initial, loading, loaded, error }

class AccountsAdminState extends Equatable {
  final AccountsAdminStatus status;
  final List<AccountItem> cuentas;
  final bool mostrarSoloActivas;
  final Object? error;

  const AccountsAdminState({
    required this.status,
    required this.cuentas,
    required this.mostrarSoloActivas,
    this.error,
  });

  factory AccountsAdminState.initial() =>
      const AccountsAdminState(status: AccountsAdminStatus.initial, cuentas: [], mostrarSoloActivas: false);

  /// Orden del original (F1.1): activas primero.
  List<AccountItem> get cuentasFiltradas {
    final lista = mostrarSoloActivas ? cuentas.where((c) => c.active).toList() : [...cuentas];
    lista.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0));
    return lista;
  }

  int get activasCount => cuentas.where((c) => c.active).length;
  int get inactivasCount => cuentas.where((c) => !c.active).length;

  AccountsAdminState copyWith({
    AccountsAdminStatus? status,
    List<AccountItem>? cuentas,
    bool? mostrarSoloActivas,
    Object? error,
    bool clearError = false,
  }) {
    return AccountsAdminState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      mostrarSoloActivas: mostrarSoloActivas ?? this.mostrarSoloActivas,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, cuentas, mostrarSoloActivas, error];
}
