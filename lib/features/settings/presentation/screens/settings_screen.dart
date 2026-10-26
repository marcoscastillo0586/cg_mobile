import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/session_providers.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/settings_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/widgets/dialog_controllers.dart';
import '../../../movements/presentation/local_write_feedback.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _monedaRechazada = 0;
  String? _diagnostico;

  /// Dispara 2 llamadas autenticadas en paralelo y muestra cuántos refresh hubo.
  Future<void> _diagnosticarSesion() async {
    final session = ref.read(sessionManagerProvider);
    final client = ref.read(dioClientProvider);
    final antes = session.refreshRequests;
    final l = context.l10n;
    setState(() => _diagnostico = 'Probando…');
    try {
      final r = await Future.wait([client.get(ApiEndpoints.me), client.get(ApiEndpoints.me)]);
      final ids = r.map((e) => (e as Map)['id']).join(', ');
      final msg = 'OK: ids [$ids] · refresh en esta prueba: ${session.refreshRequests - antes}';
      debugPrint('[DIAG] $msg');
      setState(() => _diagnostico = msg);
    } catch (e) {
      final msg = 'Error: ${ErrorMessages.describe(e, l)} (${ErrorMessages.codeOf(e) ?? '-'})';
      debugPrint('[DIAG] $msg');
      setState(() => _diagnostico = msg);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.signOut),
        content: Text(
          context.l10n.allDataStoredPhoneWill,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.signOut2, style: const TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    AppFeedback.medium();
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        children: [
          // 2. Sección: Idioma y Moneda por Defecto
          _buildSectionHeader(context.l10n.languageDefaultCurrency),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.appLanguage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settingsState.language,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(Icons.language_rounded),
                    ),
                    items: SettingsNotifier.idiomasDisponibles.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        AppFeedback.selection();
                        ref.read(settingsProvider.notifier).cambiarIdioma(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.mainCurrency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(context.l10n.mainCurrencyHint, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    // Si el servidor no la acepta, se reconstruye con la moneda que sigue vigente.
                    key: ValueKey('moneda-principal-${settingsState.defaultCurrency}-$_monedaRechazada'),
                    initialValue: settingsState.defaultCurrency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    items: SettingsNotifier.monedasDisponibles.map((code) {
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Text(SettingsNotifier.currencyLabel(code, context.l10n)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        AppFeedback.selection();
                        _cambiarMonedaPrincipal(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Sección: Sesión
          _buildSectionHeader(context.l10n.session),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('editar-nombre'),
                  leading: const Icon(Icons.person_outline_rounded),
                  // Nombre para mostrar: lo ven los integrantes de un dashboard compartido.
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editDisplayName(authState.user?.nombreUsuario ?? ''),
                  title: Text(authState.user?.nombreUsuario ?? ''),
                  subtitle: Text(
                    authState.offline
                        ? '${authState.user?.email ?? ''} · ${context.l10n.offline}'
                        : authState.user?.email ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                  title: Text(
                    context.l10n.signOut2,
                    style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    context.l10n.deletesDataStoredPhoneSettings,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _confirmarCerrarSesion(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Solo en debug: diagnóstico de la sesión (verificación de la etapa 1).
          if (kDebugMode) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(context.l10n.sessionDiagnosticsDebug),
                subtitle: Text(_diagnostico ?? context.l10n.n2ParallelGetAuthMe, style: const TextStyle(fontSize: 12)),
                onTap: _diagnosticarSesion,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 4. Sección: Módulos de Administración
          _buildSectionHeader(context.l10n.management),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                _buildAdminTile(
                  icon: Icons.dashboard_outlined,
                  color: AppColors.primary,
                  title: context.l10n.dashboards,
                  subtitle: context.l10n.manageDashboards,
                  onTap: () => context.push(AppRoutes.dashboardsAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.emerald,
                  title: context.l10n.accountsPaymentMethods,
                  subtitle: context.l10n.manageBanksWalletsCash,
                  onTap: () => context.push(AppRoutes.accountsAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.category_outlined,
                  color: AppColors.primary,
                  title: context.l10n.categories,
                  subtitle: context.l10n.createRenameActivateExpenseCategories,
                  onTap: () => context.push(AppRoutes.categoriesAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.pie_chart_outline_rounded,
                  color: AppColors.amber,
                  title: context.l10n.budgetsSpendingCaps,
                  subtitle: context.l10n.monthlyLimitsAlertsOneTap,
                  onTap: () => context.push(AppRoutes.limitsAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.analytics_outlined,
                  color: AppColors.rose,
                  title: context.l10n.reportsPriceMonitor,
                  subtitle: context.l10n.visualAnalyticsChartsInflationTrends,
                  onTap: () => context.push(AppRoutes.analytics),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Sección: Apariencia Visual
          _buildSectionHeader(context.l10n.appearanceTheme),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.displayMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded),
                        label: Text(context.l10n.system),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded),
                        label: Text(context.l10n.light),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded),
                        label: Text(context.l10n.dark),
                      ),
                    ],
                    selected: {settingsState.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      AppFeedback.selection();
                      ref.read(settingsProvider.notifier).cambiarThemeMode(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// Cambia el nombre para mostrar (con conexión; el servidor lo guarda).
  Future<void> _editDisplayName(String current) async {
    final l = context.l10n;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogControllers(
        initial: [current],
        builder: (ctx, c) => AlertDialog(
          title: Text(l.displayName),
          content: TextField(
            key: const ValueKey('nombre-para-mostrar'),
            controller: c[0],
            maxLength: 100,
            autofocus: true,
            decoration: InputDecoration(helperText: l.displayNameHint, helperMaxLines: 3),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, c[0].text.trim()), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty || name == current || !mounted) return;
    final error = await ref.read(authNotifierProvider.notifier).updateDisplayName(name);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.showError(context, describeWithCode(error, l));
    } else {
      AppFeedback.showSuccess(context, l.displayNameSaved);
    }
  }

  /// Se guarda en el servidor (la misma en la app y en la web): necesita conexión.
  Future<void> _cambiarMonedaPrincipal(String moneda) async {
    final l = context.l10n;
    final error = await ref.read(authNotifierProvider.notifier).updateMainCurrency(moneda);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.showError(context, describeWithCode(error, l));
      setState(() => _monedaRechazada++);
      return;
    }
    await ref.read(settingsProvider.notifier).cambiarMonedaDefault(moneda);
    if (mounted) AppFeedback.showSuccess(context, l.mainCurrencySaved);
  }

  Widget _buildAdminTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {
        AppFeedback.light();
        onTap();
      },
    );
  }
}
