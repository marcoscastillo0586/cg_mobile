import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/sync/sync_controller.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/date_utils.dart';
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
import '../../../../l10n/l10n.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  /// Con la app visible se actualiza sola cada 30 s: sin notificaciones push, es el retraso máximo
  /// con que aparece en el celular un cambio hecho en la web.
  static const _autoSync = Duration(seconds: 30);
  Timer? _timer;

  void _startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoSync, (_) => ref.read(syncControllerProvider.notifier).sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoSync();
      ref.read(syncControllerProvider.notifier).sync();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel(); // solo con la app visible
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// ↻ y arrastrar hacia abajo: sincronización completa (envía lo pendiente y trae lo nuevo).
  Future<void> _refresh({String? hasta}) async {
    await ref.read(syncControllerProvider.notifier).sync();
    if (!mounted) return;
    await ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: hasta);
    await ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoSync();
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
        if (mounted) AppFeedback.showError(context, context.l10n.couldNotOpenLocalDatabase(e));
      });
    });
  }

  void _seleccionarFechaFiltro(BuildContext context) async {
    final estado = ref.read(dashboardNotifierProvider);
    DateTime fechaInicial = DateTime.now();

    // fechaFiltro la arma este mismo picker (yyyy-MM-dd).
    if (estado.fechaFiltro != null) fechaInicial = DateTime.tryParse(estado.fechaFiltro!) ?? fechaInicial;

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.l10n.filterBalancesUpDate,
      confirmText: context.l10n.apply,
      cancelText: context.l10n.clear,
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

    // Los saldos salen de la base local: después de cada sincronización se recalculan.
    // Sin conexión, rechazos (quedan en Pendientes) o diferencias (se corrigen con la próxima
    // descarga completa) no muestran avisos; solo un error inesperado, que no es de red.
    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (syncFinished(prev, next)) {
        ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: ref.read(dashboardNotifierProvider).fechaFiltro);
        ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
      }
      if (prev?.status != next.status && next.status == SyncStatus.error && next.error != null) {
        AppFeedback.showError(
          context,
          '${context.l10n.syncFailed2}: ${ErrorMessages.describe(next.error!, context.l10n)}',
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.expenses2,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          const NotificationBellWidget(),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: context.l10n.reportsAnalytics,
            onPressed: () {
              AppFeedback.light();
              context.push(AppRoutes.analytics);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshBalances,
            onPressed: () {
              AppFeedback.light();
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.settings,
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
          await _refresh(hasta: dashboardState.fechaFiltro);
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
                        ErrorMessages.describe(error, context.l10n) + (code != null ? '\n($code)' : ''),
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
                        child: Text(context.l10n.retry),
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
            final rateError = balances.rateError;
            final String? cotizacion;
            if (rate.isNotApplicable) {
              cotizacion = null; // ninguna cuenta en USD: no hace falta cotización
            } else if (rate.available && !rate.isStale) {
              cotizacion = '${rate.name}: ${Money.format(rate.sellCents)}';
            } else if (rate.available) {
              // Última cotización recibida, con su fecha (no hay cotización fija).
              final cuando = AppDateUtils.formatDateTimeString(DateTime.parse(rate.receivedAt!).toLocal().toIso8601String());
              cotizacion = '${context.l10n.lastRate} ($cuando) ${rate.name}: ${Money.format(rate.sellCents)}';
            } else {
              cotizacion = rateError == null || rateError is NetworkException
                  ? (context.l10n.exchangeRateOfflineUsdNot)
                  : '${context.l10n.exchangeRateUnavailableUsdNot}: '
                      '${ErrorMessages.describe(rateError, context.l10n)}';
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              children: [
                if (dashboardState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${context.l10n.showingLastLoadedData}: '
                      '${ErrorMessages.describe(dashboardState.error!, context.l10n)}',
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
                              context.l10n.myAccountsAccounts(balances.accounts.length),
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
                                    context.l10n.limitsBudgets,
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
                    return AccountCard(account: cuenta,
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
