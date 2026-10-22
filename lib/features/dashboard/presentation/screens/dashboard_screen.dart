import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/dashboard_skeleton.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/presentation/widgets/onboarding_dialog.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/dashboard_state.dart';
import '../providers/novedades_notifier.dart';
import '../widgets/account_card.dart';
import '../widgets/balance_card.dart';
import '../widgets/notification_bell_widget.dart';
import '../widgets/quick_actions_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final settings = ref.read(settingsProvider);
      if (settings.isFirstLaunch && mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => OnboardingDialog(
            initialMoneda: settings.defaultCurrency,
            initialIdioma: settings.language,
            onConfirmar: ({required String moneda, required String idioma}) {
              ref.read(settingsProvider.notifier).guardarConfiguracionInicial(
                    moneda: moneda,
                    idioma: idioma,
                  );
            },
          ),
        );
      }
      ref.read(novedadesNotifierProvider.notifier).calcularNovedades();

      // Crea o migra la base local al entrar; si no se puede abrir, se avisa.
      // Crea o migra la base local y descarga los cambios del servidor (pull).
      ref.read(localDatabaseProvider).then<void>((_) {
        if (mounted) ref.read(syncControllerProvider.notifier).sync();
      }, onError: (Object e) {
        debugPrint('[DB] No se pudo abrir la base local: $e');
        if (mounted) AppFeedback.showError(context, 'No se pudo abrir la base local: $e');
      });
    });
  }

  void _seleccionarFechaFiltro(BuildContext context) async {
    final estado = ref.read(dashboardNotifierProvider);
    DateTime fechaInicial = DateTime.now();

    if (estado.fechaFiltro != null) {
      try {
        fechaInicial = DateTime.parse(estado.fechaFiltro!);
      } catch (_) {}
    }

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Filtrar saldos hasta fecha',
      confirmText: 'Aplicar',
      cancelText: 'Limpiar',
    );

    if (seleccionada != null) {
      final formato = DateFormat('yyyy-MM-dd').format(seleccionada);
      unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: formato));
    } else {
      unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(settingsProvider).language == 'en';

    // La sincronización avisa si falla o si la base local no coincide con el servidor.
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (prev?.status == next.status) return;
      if (next.status == SyncStatus.error && next.error != null) {
        AppFeedback.showError(
          context,
          '${isEn ? 'Sync failed' : 'No se pudo sincronizar'}: ${ErrorMessages.describe(next.error!, isEn: isEn)}',
        );
      } else if (next.status == SyncStatus.mismatch) {
        AppFeedback.showError(
          context,
          isEn ? 'Local data does not match the server; a full download will run next time.'
               : 'Los datos locales no coinciden con el servidor; la próxima vez se descarga todo.',
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gastos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          const NotificationBellWidget(),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Reportes y Analíticas',
            onPressed: () {
              AppFeedback.light();
              context.push(AppRoutes.analytics);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar saldos',
            onPressed: () {
              AppFeedback.light();
              ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
              ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes y Configuración',
            onPressed: () {
              AppFeedback.light();
              context.push(AppRoutes.settings);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: dashboardState.fechaFiltro);
          await ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
        },
        child: Builder(
          builder: (context) {
            final balances = dashboardState.balances;
            if (dashboardState.status == DashboardStatus.loading && balances == null) {
              return const DashboardSkeleton();
            }

            if (dashboardState.status == DashboardStatus.error && balances == null) {
              final error = dashboardState.error!;
              final code = ErrorMessages.codeOf(error);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.rose),
                      const SizedBox(height: 16),
                      Text(
                        ErrorMessages.describe(error, isEn: isEn) + (code != null ? '\n($code)' : ''),
                        key: const ValueKey('dashboard-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          AppFeedback.light();
                          ref.read(dashboardNotifierProvider.notifier).cargarDashboard();
                          ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (balances == null) {
              return const SizedBox.shrink();
            }
            final rate = balances.exchangeRate;
            final cotizacion = rate.available
                ? '${rate.name}: ${Money.format(rate.sellCents)}'
                : (isEn ? 'Exchange rate: offline (1.00)' : 'Cotización: sin conexión (1,00)');

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              children: [
                if (dashboardState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${isEn ? 'Showing the last loaded data' : 'Se muestran los datos de la última carga'}: '
                      '${ErrorMessages.describe(dashboardState.error!, isEn: isEn)}',
                      style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                BalanceCard(
                  totalArsCents: dashboardState.totalSeleccionadoArsCents,
                  cotizacionTexto: cotizacion,
                  ocultarMontos: dashboardState.ocultarMontos,
                  fechaFiltro: dashboardState.fechaFiltro,
                  onToggleOcultar: () {
                    AppFeedback.selection();
                    ref.read(dashboardNotifierProvider.notifier).toggleVisibilidadMontos();
                  },
                  onSelectFecha: () => _seleccionarFechaFiltro(context),
                ),
                const SizedBox(height: 20),

                QuickActionsBar(
                  onNuevoGasto: () {
                    AppFeedback.light();
                    context.push(AppRoutes.expensesCreate);
                  },
                  onNuevoIngreso: () {
                    AppFeedback.light();
                    context.push(AppRoutes.incomesCreate);
                  },
                  onNuevaTransferencia: () {
                    AppFeedback.light();
                    context.push(AppRoutes.transfersCreate);
                  },
                  onVerHistorial: () {
                    AppFeedback.light();
                    context.push(AppRoutes.movements);
                  },
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Mis Cuentas (${balances.accounts.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            AppFeedback.light();
                            context.push(AppRoutes.limitsAdmin);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Límites y Presupuestos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: isDark ? Colors.white70 : AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...balances.accounts.map(
                  (cuenta) {
                    final isSelected = dashboardState.idsSeleccionados.contains(cuenta.id);
                    return AccountCard(
                      account: cuenta,
                      ocultarMontos: dashboardState.ocultarMontos,
                      isSelected: isSelected,
                      onToggleSelection: (_) {
                        AppFeedback.selection();
                        ref
                            .read(dashboardNotifierProvider.notifier)
                            .toggleCuentaSeleccionada(cuenta.id);
                      },
                      onTap: () {
                        context.push(
                          '${AppRoutes.movements}?id_lugar=${cuenta.id}&nombre=${Uri.encodeComponent(cuenta.name)}',
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}
