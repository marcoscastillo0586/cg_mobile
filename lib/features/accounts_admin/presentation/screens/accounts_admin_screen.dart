import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../domain/entities/account_admin_entity.dart';
import '../providers/accounts_admin_notifier.dart';
import '../providers/accounts_admin_state.dart';
import '../widgets/account_form_dialog.dart';

class AccountsAdminScreen extends ConsumerStatefulWidget {
  const AccountsAdminScreen({super.key});

  @override
  ConsumerState<AccountsAdminScreen> createState() => _AccountsAdminScreenState();
}

class _AccountsAdminScreenState extends ConsumerState<AccountsAdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas();
    });
  }

  void _abrirFormulario({AccountAdminEntity? cuenta}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AccountFormDialog(
        cuenta: cuenta,
        onGuardar: ({
          required String nombre,
          required int tipoMoneda,
          required bool activo,
          String? img,
        }) async {
          if (cuenta == null) {
            return await ref
                .read(accountsAdminNotifierProvider.notifier)
                .crearCuenta(nombre: nombre, tipoMoneda: tipoMoneda, img: img);
          } else {
            return await ref
                .read(accountsAdminNotifierProvider.notifier)
                .editarCuenta(
                  idLugar: cuenta.idLugar,
                  nombre: nombre,
                  tipoMoneda: tipoMoneda,
                  activo: activo,
                );
          }
        },
      ),
    );
  }

  void _solicitarDesactivacion(AccountAdminEntity cuenta) async {
    final state = ref.read(accountsAdminNotifierProvider);

    // Caso 3: Si es la única cuenta existente en el sistema
    if (state.cuentas.length <= 1) {
      AppFeedback.showError(
        context,
        'No es posible desactivar la única cuenta existente en el sistema',
      );
      return;
    }

    // Caso 1: Si la cuenta tiene saldo $0
    if (cuenta.saldoActual.abs() < 0.001) {
      await ref
          .read(accountsAdminNotifierProvider.notifier)
          .toggleEstado(idLugar: cuenta.idLugar, nuevoActivo: false);
      return;
    }

    // Caso 2: Si la cuenta tiene saldo > 0
    final nombreMoneda = cuenta.esUsd ? 'USD' : 'ARS';
    final otrasCuentasMismaMoneda = state.cuentas.where((c) {
      return c.idLugar != cuenta.idLugar &&
          c.activo &&
          c.tipoMoneda == cuenta.tipoMoneda;
    }).toList();

    // Bloquear si no existe otra cuenta activa en la misma moneda
    if (otrasCuentasMismaMoneda.isEmpty) {
      AppFeedback.showError(
        context,
        'No es posible desactivar la cuenta con saldo porque no existe otra cuenta activa en $nombreMoneda para transferir los fondos',
      );
      return;
    }

    // Diálogo para seleccionar la cuenta destino activa de la misma divisa
    int? cuentaDestinoSeleccionadaId = otrasCuentasMismaMoneda.first.idLugar;

    if (!mounted) return;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text('Transferir Fondos', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La cuenta "${cuenta.nombre}" posee un saldo de ${AppCurrencyUtils.format(cuenta.saldoActual, symbol: cuenta.esUsd ? 'US\$' : '\$')}. Para poder desactivarla, debes transferir la totalidad de los fondos a otra cuenta activa en $nombreMoneda.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona la cuenta destino:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: cuentaDestinoSeleccionadaId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: otrasCuentasMismaMoneda.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.idLugar,
                        child: Text('${c.nombre} (${AppCurrencyUtils.format(c.saldoActual, symbol: c.esUsd ? 'US\$' : '\$')})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => cuentaDestinoSeleccionadaId = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (cuentaDestinoSeleccionadaId == null) return;
                    Navigator.of(dialogCtx).pop();

                    final okTransfer = await ref
                        .read(accountsAdminNotifierProvider.notifier)
                        .transferirYDesactivar(
                          idOrigen: cuenta.idLugar,
                          idDestino: cuentaDestinoSeleccionadaId!,
                          monto: cuenta.saldoActual,
                          monedaSimbolo: nombreMoneda,
                        );

                    if (okTransfer && mounted) {
                      AppFeedback.showSuccess(
                        context,
                        'Fondos transferidos y cuenta "${cuenta.nombre}" desactivada con éxito',
                      );
                    }
                  },
                  child: const Text('Transferir y Desactivar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmarEliminacion(AccountAdminEntity cuenta) {
    if (cuenta.activo) {
      _solicitarDesactivacion(cuenta);
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 24),
              SizedBox(width: 10),
              Text('Eliminar Cuenta'),
            ],
          ),
          content: Text(
            '¿Estás seguro de eliminar permanentemente la cuenta "${cuenta.nombre}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(accountsAdminNotifierProvider.notifier)
                    .eliminarCuenta(cuenta.idLugar);
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsAdminNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AccountsAdminState>(accountsAdminNotifierProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppFeedback.showError(context, next.errorMessage!);
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        AppFeedback.showSuccess(context, next.successMessage!);
      }
    });

    final cuentas = state.cuentasFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas y Billeteras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar cuentas',
            onPressed: () {
              AppFeedback.light();
              ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Cuenta'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas();
        },
        child: Column(
          children: [
            // Filtros y contadores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Todas (${state.cuentas.length})'),
                    selected: !state.mostrarSoloActivas,
                    onSelected: (_) {
                      AppFeedback.selection();
                      if (state.mostrarSoloActivas) {
                        ref.read(accountsAdminNotifierProvider.notifier).toggleFiltroSoloActivas();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Solo Activas (${state.activasCount})'),
                    selected: state.mostrarSoloActivas,
                    selectedColor: AppColors.emerald.withValues(alpha: 0.2),
                    onSelected: (_) {
                      AppFeedback.selection();
                      if (!state.mostrarSoloActivas) {
                        ref.read(accountsAdminNotifierProvider.notifier).toggleFiltroSoloActivas();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.status == AccountsAdminStatus.loading && state.cuentas.isEmpty) {
                    return ShimmerEffect(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) => Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  }

                  if (state.status == AccountsAdminStatus.error && state.cuentas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.rose),
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage ?? 'Error al cargar las cuentas',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(accountsAdminNotifierProvider.notifier).cargarCuentas();
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (cuentas.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 54, color: AppColors.lightTextSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No hay cuentas registradas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Crea una cuenta con el botón "+" inferior',
                            style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: cuentas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = cuentas[index];
                      final colorMoneda = item.esUsd ? AppColors.emerald : AppColors.primary;

                      return Card(
                        elevation: item.activo ? 1.5 : 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: item.activo
                                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                : AppColors.rose.withValues(alpha: 0.3),
                            width: item.activo ? 1 : 1.2,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _abrirFormulario(cuenta: item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                // Icono / Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorMoneda.withValues(alpha: item.activo ? 0.12 : 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    item.esUsd ? Icons.attach_money_rounded : Icons.account_balance_rounded,
                                    color: item.activo ? colorMoneda : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nombre, detalles y saldo
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.nombre.toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: item.activo
                                                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                                    : Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorMoneda.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.monedaSimbolo,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colorMoneda,
                                              ),
                                            ),
                                          ),
                                          if (!item.activo) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.rose.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'INACTIVA',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.rose,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${item.cantidadMovimientos} movimientos',
                                            style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                          ),
                                          Text(
                                            AppCurrencyUtils.format(item.saldoActual, symbol: item.esUsd ? 'US\$' : '\$'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: item.saldoActual < 0 ? AppColors.rose : AppColors.emerald,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Menú de acciones
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                                  onSelected: (val) {
                                    AppFeedback.selection();
                                    if (val == 'editar') {
                                      _abrirFormulario(cuenta: item);
                                    } else if (val == 'estado') {
                                      if (item.activo) {
                                        _solicitarDesactivacion(item);
                                      } else {
                                        ref
                                            .read(accountsAdminNotifierProvider.notifier)
                                            .toggleEstado(idLugar: item.idLugar, nuevoActivo: true);
                                      }
                                    } else if (val == 'eliminar') {
                                      _confirmarEliminacion(item);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 10),
                                          Text('Editar'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'estado',
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.activo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(item.activo ? 'Desactivar' : 'Activar'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rose),
                                          SizedBox(width: 10),
                                          Text('Eliminar', style: TextStyle(color: AppColors.rose)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
