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
import '../../../../core/widgets/bottom_safe_area.dart';

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
      final msg = 'Error: ${ErrorMessages.withCode(e, l)}';
      debugPrint('[DIAG] $msg');
      setState(() => _diagnostico = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authNotifierProvider);
    final email = auth.user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0).withBottomSafeArea(context),
        children: [
          _Seccion(
            titulo: l10n.management,
            child: Column(children: [
              _AdminTile(Icons.dashboard_outlined, AppColors.primary, l10n.dashboards, l10n.manageDashboards, AppRoutes.dashboardsAdmin),
              const Divider(height: 1),
              _AdminTile(Icons.account_balance_wallet_outlined, AppColors.emerald, l10n.accountsPaymentMethods, l10n.manageBanksWalletsCash,
                  AppRoutes.accountsAdmin),
              const Divider(height: 1),
              _AdminTile(Icons.category_outlined, AppColors.primary, l10n.categories2, l10n.createRenameActivateExpenseCategories,
                  AppRoutes.categoriesAdmin),
              const Divider(height: 1),
              _AdminTile(Icons.pie_chart_outline_rounded, AppColors.amber, l10n.budgetsSpendingCaps, l10n.monthlyLimitsAlertsOneTap,
                  AppRoutes.limitsAdmin),
            ]),
          ),
          _Seccion(
            titulo: l10n.session,
            child: ListTile(
              key: const ValueKey('editar-nombre'),
              leading: const Icon(Icons.person_outline_rounded),
              // Nombre para mostrar: lo ven los integrantes de un dashboard compartido.
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _editDisplayName(auth.user?.nombreUsuario ?? ''),
              title: Text(auth.user?.nombreUsuario ?? ''),
              subtitle: Text(auth.offline ? '$email · ${l10n.offline}' : email, style: const TextStyle(fontSize: 12)),
            ),
          ),
          // Solo en debug: diagnóstico de la sesión (verificación de la etapa 1).
          if (kDebugMode)
            _Seccion(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.sessionDiagnosticsDebug),
                subtitle: Text(_diagnostico ?? l10n.n2ParallelGetAuthMe, style: const TextStyle(fontSize: 12)),
                onTap: _diagnosticarSesion,
              ),
            ),
          _Seccion(
            titulo: l10n.languageDefaultCurrency,
            padding: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appLanguage, style: _negrita),
                const SizedBox(height: 8),
                _Selector(
                  key: const ValueKey('idioma'),
                  value: settings.language,
                  icon: Icons.language_rounded,
                  opciones: SettingsNotifier.idiomasDisponibles,
                  onChanged: ref.read(settingsProvider.notifier).cambiarIdioma,
                ),
                const SizedBox(height: 16),
                Text(l10n.mainCurrency, style: _negrita),
                Text(l10n.mainCurrencyHint, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                const SizedBox(height: 8),
                _Selector(
                  // Si el servidor no la acepta, se reconstruye con la moneda que sigue vigente.
                  key: ValueKey('moneda-principal-${settings.defaultCurrency}-$_monedaRechazada'),
                  value: settings.defaultCurrency,
                  icon: Icons.attach_money_rounded,
                  opciones: {for (final code in SettingsNotifier.monedasDisponibles) code: SettingsNotifier.currencyLabel(code, l10n)},
                  onChanged: _cambiarMonedaPrincipal,
                ),
              ],
            ),
          ),
          _Seccion(
            titulo: l10n.appearanceTheme,
            padding: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.displayMode, style: _negrita),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(l10n.system)),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(l10n.light)),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(l10n.dark)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    AppFeedback.selection();
                    ref.read(settingsProvider.notifier).cambiarThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static const _negrita = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);

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
}

/// Título (opcional) y tarjeta con borde.
class _Seccion extends StatelessWidget {
  final String? titulo;
  final double? padding;
  final Widget child;
  const _Seccion({this.titulo, this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = titulo;
    final p = padding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: p == null ? child : Padding(padding: EdgeInsets.all(p), child: child),
          ),
        ],
      ),
    );
  }
}

/// Desplegable de una opción (valor → texto).
class _Selector extends StatelessWidget {
  final String value;
  final IconData icon;
  final Map<String, String> opciones;
  final ValueChanged<String> onChanged;
  const _Selector({super.key, required this.value, required this.icon, required this.opciones, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: Icon(icon),
        ),
        items: [for (final e in opciones.entries) DropdownMenuItem<String>(value: e.key, child: Text(e.value))],
        onChanged: (val) {
          if (val == null) return;
          AppFeedback.selection();
          onChanged(val);
        },
      );
}

/// Acceso a una pantalla de administración.
class _AdminTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
  const _AdminTile(this.icon, this.color, this.title, this.subtitle, this.route);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () {
          AppFeedback.light();
          context.push(route);
        },
      );
}
