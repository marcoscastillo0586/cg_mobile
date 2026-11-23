import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/presentation/widgets/onboarding_dialog.dart';
import '../../domain/entities/balances.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/dashboard_state.dart';
import '../providers/novedades_notifier.dart';
import '../widgets/account_card.dart';
import '../widgets/balance_card.dart';
import '../widgets/notification_bell_widget.dart';
import '../widgets/quick_actions_bar.dart';
import '../../../../l10n/l10n.dart';
import '../../../dashboards/presentation/dashboard_widgets.dart';
import '../../../dashboards/presentation/dashboards_notifier.dart';
import '../../../../core/dashboards/current_dashboard.dart';
import '../../../../core/dashboards/live_events.dart';
import '../../../../core/update/update_dialog.dart';
import '../../../../core/widgets/bottom_safe_area.dart';

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

  /// Apenas el celular recupera una red (wifi o datos) se sincroniza, sin esperar el ciclo de 30 s.
  StreamSubscription<List<ConnectivityResult>>? _network;
  var _hadNetwork = true;

  /// Avisos en vivo (invitaciones, cambios de otros integrantes) mientras la app está visible.
  LiveEvents? _events;

  /// Invitación que se está mostrando (para no abrir la ventana dos veces).
  int? _showingInvitation;

  SyncController get _sync => ref.read(syncControllerProvider.notifier);

  static bool _hasNetwork(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

  void _onNetworkChanged(List<ConnectivityResult> results) {
    final hasNetwork = _hasNetwork(results);
    final visible = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    // sync() fuerza el intento: no espera la ventana de "sin conexión" recordada (30 s).
    if (hasNetwork && !_hadNetwork && visible && mounted) _sync.sync();
    _hadNetwork = hasNetwork;
  }

  void _onLiveEvent(LiveEvent e) {
    if (!mounted) return;
    final dashboards = ref.read(dashboardsNotifierProvider.notifier);
    switch (e.type) {
      case 'invitation':
        dashboards.loadInvitations();
      case 'notification':
        dashboards.loadNotifications();
      case 'dashboard-changed':
        // Otro integrante cambió algo en el dashboard que se está viendo: se trae ya.
        if (e.dashboardId != null && e.dashboardId == dashboards.current?.id) _sync.sync();
      case 'dashboards-changed' || 'access-removed':
        dashboards.refresh();
    }
  }

  /// Aviso único al volver al principal porque se perdió el acceso al dashboard elegido.
  void _showNotice() {
    if (CurrentDashboard.notice.value != CurrentDashboard.accessLost || !mounted) return;
    CurrentDashboard.notice.value = null;
    AppFeedback.showError(context, context.l10n.accessLostNotice);
  }

  void _startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoSync, (_) => _sync.sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoSync();
      _events?.start();
      _sync.sync();
      ref.read(dashboardsNotifierProvider.notifier).refresh();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel(); // solo con la app visible
      _events?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _network?.cancel();
    _events?.stop();
    CurrentDashboard.notice.removeListener(_showNotice);
    super.dispose();
  }

  /// ↻ y arrastrar hacia abajo: sincronización completa (envía lo pendiente y trae lo nuevo).
  Future<void> _refresh({String? hasta}) async {
    await _sync.sync();
    if (!mounted) return;
    await ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: hasta);
    await ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoSync();
    _listenNetwork();
    _events = ref.read(liveEventsProvider)(_onLiveEvent)..start();
    CurrentDashboard.notice.addListener(_showNotice);
    Future.microtask(_alEntrar);
  }

  void _listenNetwork() {
    final connectivity = Connectivity();
    // then<void>: con un onError que no devuelve nada, el tipo del futuro no puede ser bool (ArgumentError).
    connectivity.checkConnectivity().then<void>((r) => _hadNetwork = _hasNetwork(r), onError: (Object e) {
      debugPrint('[RED] No se pudo leer el estado de la red: $e');
    });
    _network = connectivity.onConnectivityChanged.listen(_onNetworkChanged, onError: (Object e) {
      // Sin aviso de cambios de red quedan el ciclo de 30 s y la vuelta a la app.
      debugPrint('[RED] No se pueden escuchar los cambios de red: $e');
    });
  }

  /// Al entrar: ajustes de la cuenta, primer ingreso o moneda principal, novedades, actualización y base local.
  Future<void> _alEntrar() async {
    _showNotice();
    final settingsNotifier = ref.read(settingsProvider.notifier);
    await settingsNotifier.listo;
    final usuario = ref.read(authNotifierProvider).user;
    // Moneda principal y primer ingreso son de cada cuenta (otra cuenta del celular tiene los suyos).
    if (usuario != null) await settingsNotifier.cargarCuenta(usuario.idUsuario);
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    if (settings.isFirstLaunch) {
      _mostrarPrimerIngreso(settings, usuario?.monedaPrincipal);
    } else {
      await _acordarMoneda(settings.defaultCurrency, usuario?.monedaPrincipal);
    }
    if (!mounted) return;
    unawaited(ref.read(novedadesNotifierProvider.notifier).calcularNovedades());
    // Versión nueva publicada (no en el primer ingreso: está el diálogo inicial).
    if (!settings.isFirstLaunch) unawaited(UpdatePrompt.checkOnce(context));
    _abrirBase();
  }

  void _mostrarPrimerIngreso(SettingsState settings, String? monedaServidor) {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OnboardingDialog(
        // Si ya la eligió en la web u otro celular, viene preseleccionada.
        initialMoneda: monedaServidor ?? settings.defaultCurrency,
        initialIdioma: settings.language,
        onConfirmar: ({required String moneda, required String idioma, required String nombreDashboard}) {
          ref.read(settingsProvider.notifier).guardarConfiguracionInicial(moneda: moneda, idioma: idioma);
          // Moneda principal en el servidor; sin conexión se envía en el próximo ingreso (_acordarMoneda).
          ref.read(authNotifierProvider.notifier).updateMainCurrency(moneda);
          // Sin conexión queda pendiente y se envía en la próxima carga de la lista.
          ref.read(dashboardsNotifierProvider.notifier).namePrincipal(nombreDashboard);
        },
      ),
    ));
  }

  /// La moneda del servidor manda (pudo cambiarse en la web u otro celular). Si el servidor todavía no la
  /// tiene (instalaciones anteriores o elegida sin conexión), se envía la de este celular.
  Future<void> _acordarMoneda(String local, String? servidor) async {
    if (servidor == null) {
      unawaited(ref.read(authNotifierProvider.notifier).updateMainCurrency(local));
    } else if (servidor != local) {
      await ref.read(settingsProvider.notifier).cambiarMonedaDefault(servidor);
    }
  }

  /// Crea o migra la base local y descarga los cambios del servidor; si no se puede abrir, se avisa.
  void _abrirBase() {
    unawaited(ref.read(localDatabaseProvider).then<void>((_) {
      if (mounted) _sync.sync();
    }, onError: (Object e) {
      debugPrint('[DB] No se pudo abrir la base local: $e');
      if (mounted) AppFeedback.showError(context, context.l10n.couldNotOpenLocalDatabase(e));
    }));
  }

  Future<void> _seleccionarFechaFiltro(BuildContext context) async {
    // fechaFiltro la arma este mismo picker (yyyy-MM-dd).
    final filtro = ref.read(dashboardNotifierProvider).fechaFiltro;
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(filtro ?? '') ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.l10n.filterBalancesUpDate,
      confirmText: context.l10n.apply,
      cancelText: context.l10n.clear,
    );
    // "Limpiar" (o cerrar) vuelve a los saldos de hoy.
    final hasta = seleccionada == null ? null : DateFormat('yyyy-MM-dd').format(seleccionada);
    unawaited(ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: hasta));
  }

  /// Invitación recibida: la ventana aparece sola (una a la vez).
  void _onDashboardsChanged(DashboardsState? prev, DashboardsState next) {
    final inv = next.invitations.firstOrNull;
    if (inv == null || inv.id == _showingInvitation) return;
    _showingInvitation = inv.id;
    showInvitationDialog(context, ref, inv).whenComplete(() => _showingInvitation = null);
  }

  /// Los saldos salen de la base local: después de cada sincronización se recalculan. Sin conexión, rechazos
  /// (quedan en Pendientes) o diferencias (se corrigen con la próxima descarga completa) no muestran avisos;
  /// solo un error inesperado, que no es de red.
  void _onSyncChanged(SyncState? prev, SyncState next) {
    if (syncFinished(prev, next)) {
      ref.read(dashboardNotifierProvider.notifier).cargarDashboard(hasta: ref.read(dashboardNotifierProvider).fechaFiltro);
      ref.read(novedadesNotifierProvider.notifier).calcularNovedades();
    }
    final error = next.error;
    if (prev?.status != next.status && next.status == SyncStatus.error && error != null) {
      AppFeedback.showError(context, '${context.l10n.syncFailed2}: ${ErrorMessages.describe(error, context.l10n)}');
    }
  }

  void _ir(String route) {
    AppFeedback.light();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    ref.listen<DashboardsState>(dashboardsNotifierProvider, _onDashboardsChanged);
    ref.listen<SyncState>(syncControllerProvider, _onSyncChanged);
    final dashboardsState = ref.watch(dashboardsNotifierProvider);
    final dashboards = ref.read(dashboardsNotifierProvider.notifier);
    final current = dashboards.current;
    final nombreDashboard = current == null ? null : dashboards.label(current, context.l10n);
    final balances = dashboardState.balances;

    return Scaffold(
      appBar: AppBar(
        // Con más de un dashboard, el título dice cuál se está viendo.
        title: Text(
          dashboardsState.dashboards.length > 1 ? nombreDashboard ?? context.l10n.expenses2 : context.l10n.expenses2,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const NotificationBellWidget(),
          const DashboardSelector(),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: context.l10n.reportsAnalytics,
            onPressed: () => _ir(AppRoutes.analytics),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.settings,
            onPressed: () => _ir(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppFeedback.light();
          await _refresh(hasta: dashboardState.fechaFiltro);
        },
        child: switch (dashboardState.status) {
          _ when balances != null => _Saldos(
              state: dashboardState,
              balances: balances,
              nombreDashboard: nombreDashboard,
              onSelectFecha: () => _seleccionarFechaFiltro(context),
              onIr: _ir,
            ),
          DashboardStatus.loading => const DashboardSkeleton(),
          DashboardStatus.error => _ErrorCarga(error: dashboardState.error!),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// Primera carga fallida (sin saldos anteriores para mostrar): el motivo y "Reintentar".
class _ErrorCarga extends ConsumerWidget {
  final Object error;
  const _ErrorCarga({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.rose),
            const SizedBox(height: 16),
            Text(
              ErrorMessages.withCode(error, context.l10n, sep: '\n'),
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
}

/// Totales, accesos rápidos y cuentas. Moneda principal (elegida en el primer ingreso): total grande; las
/// otras monedas con cuentas, más chicas. Sin conversión entre monedas.
class _Saldos extends ConsumerWidget {
  final DashboardState state;
  final Balances balances;
  final String? nombreDashboard;
  final VoidCallback onSelectFecha;
  final void Function(String route) onIr;

  const _Saldos({required this.state, required this.balances, required this.nombreDashboard, required this.onSelectFecha, required this.onIr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principal = Currency.parse(ref.watch(settingsProvider.select((s) => s.defaultCurrency)));
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    final error = state.error;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0).withBottomSafeArea(context),
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${context.l10n.showingLastLoadedData}: ${ErrorMessages.describe(error, context.l10n)}',
              style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        BalanceCard(
          monedaPrincipal: principal,
          totalPrincipalCents: state.totalSeleccionadoCents(principal),
          otrosTotales: [
            for (final moneda in Currency.values)
              if (moneda != principal && balances.currencies.contains(moneda)) (moneda, state.totalSeleccionadoCents(moneda)),
          ],
          ocultarMontos: state.ocultarMontos,
          fechaFiltro: state.fechaFiltro,
          nombreDashboard: nombreDashboard,
          onToggleOcultar: () {
            AppFeedback.selection();
            notifier.toggleVisibilidadMontos();
          },
          onSelectFecha: onSelectFecha,
        ),
        const SizedBox(height: 20),
        QuickActionsBar(
          onNuevoGasto: () => onIr(AppRoutes.expensesCreate),
          onNuevoIngreso: () => onIr(AppRoutes.incomesCreate),
          onNuevaTransferencia: () => onIr(AppRoutes.transfersCreate),
          onVerHistorial: () => onIr(AppRoutes.movements),
        ),
        const SizedBox(height: 24),
        _Pestanas(cuentas: balances.accounts.length, onLimites: () => onIr(AppRoutes.limitsAdmin)),
        const SizedBox(height: 16),
        for (final cuenta in balances.accounts)
          AccountCard(
            account: cuenta,
            ocultarMontos: state.ocultarMontos,
            isSelected: state.idsSeleccionados.contains(cuenta.id),
            onToggleSelection: (_) {
              AppFeedback.selection();
              notifier.toggleCuentaSeleccionada(cuenta.id);
            },
            onTap: () => context.push(historialDe(cuenta)),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// El historial filtra por el id del servidor (no el del celular). Una cuenta todavía sin enviar no tiene: se
/// abre el historial general.
@visibleForTesting
String historialDe(BalanceAccount cuenta) {
  final serverId = cuenta.serverId;
  return serverId == null ? AppRoutes.movements : '${AppRoutes.movements}?id_lugar=$serverId&nombre=${Uri.encodeComponent(cuenta.name)}';
}

/// "Mis cuentas (n)" (la vista actual) y el acceso a "Límites".
class _Pestanas extends StatelessWidget {
  final int cuentas;
  final VoidCallback onLimites;
  const _Pestanas({required this.cuentas, required this.onLimites});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? Colors.white70 : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  context.l10n.myAccountsAccounts(cuentas),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              key: const ValueKey('ir-limites'),
              onTap: onLimites,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.limitsBudgets,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: linkColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: linkColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
