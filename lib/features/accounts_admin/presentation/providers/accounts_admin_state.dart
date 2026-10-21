import 'package:equatable/equatable.dart';
import '../../domain/entities/account_admin_entity.dart';

enum AccountsAdminStatus { initial, loading, loaded, error }

class AccountsAdminState extends Equatable {
  final AccountsAdminStatus status;
  final List<AccountAdminEntity> cuentas;
  final bool mostrarSoloActivas;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const AccountsAdminState({
    required this.status,
    required this.cuentas,
    required this.mostrarSoloActivas,
    required this.isSaving,
    this.errorMessage,
    this.successMessage,
  });

  factory AccountsAdminState.initial() {
    return const AccountsAdminState(
      status: AccountsAdminStatus.initial,
      cuentas: [],
      mostrarSoloActivas: false,
      isSaving: false,
    );
  }

  List<AccountAdminEntity> get cuentasFiltradas {
    if (mostrarSoloActivas) {
      return cuentas.where((c) => c.activo).toList();
    }
    return cuentas;
  }

  int get activasCount => cuentas.where((c) => c.activo).length;
  int get inactivasCount => cuentas.where((c) => !c.activo).length;

  AccountsAdminState copyWith({
    AccountsAdminStatus? status,
    List<AccountAdminEntity>? cuentas,
    bool? mostrarSoloActivas,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AccountsAdminState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      mostrarSoloActivas: mostrarSoloActivas ?? this.mostrarSoloActivas,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        cuentas,
        mostrarSoloActivas,
        isSaving,
        errorMessage,
        successMessage,
      ];
}
