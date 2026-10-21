import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/session_providers.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _diagnostico;

  /// Dispara 2 llamadas autenticadas en paralelo y muestra cuántos refresh hubo.
  Future<void> _diagnosticarSesion() async {
    final session = ref.read(sessionManagerProvider);
    final client = ref.read(dioClientProvider);
    final antes = session.refreshRequests;
    setState(() => _diagnostico = 'Probando…');
    try {
      final r = await Future.wait([client.get(ApiEndpoints.me), client.get(ApiEndpoints.me)]);
      final ids = r.map((e) => (e as Map)['id']).join(', ');
      final msg = 'OK: ids [$ids] · refresh en esta prueba: ${session.refreshRequests - antes}';
      debugPrint('[DIAG] $msg');
      setState(() => _diagnostico = msg);
    } catch (e) {
      final msg = 'Error: ${ErrorMessages.describe(e, isEn: false)} (${ErrorMessages.codeOf(e) ?? '-'})';
      debugPrint('[DIAG] $msg');
      setState(() => _diagnostico = msg);
    }
  }

  Future<void> _confirmarCerrarSesion(bool isEn) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Sign out?' : '¿Cerrar sesión?'),
        content: Text(
          isEn
              ? 'All data stored on this phone will be deleted. Data already on the server is not affected.'
              : 'Se borrarán todos los datos guardados en este celular. Lo que ya está en el servidor no se toca.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(isEn ? 'Cancel' : 'Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEn ? 'Sign out' : 'Cerrar sesión', style: const TextStyle(color: AppColors.rose)),
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
    final isEn = settingsState.language == 'en';
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes y Configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        children: [
          // 2. Sección: Idioma y Moneda por Defecto
          _buildSectionHeader('Idioma y Moneda por Defecto'),
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
                  const Text('Idioma de la Aplicación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  const Text('Moneda por Defecto (al crear cuentas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settingsState.defaultCurrency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    items: SettingsNotifier.monedasDisponibles.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        AppFeedback.selection();
                        ref.read(settingsProvider.notifier).cambiarMonedaDefault(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Sección: Sesión
          _buildSectionHeader(isEn ? 'Session' : 'Sesión'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(authState.user?.nombreUsuario ?? ''),
                  subtitle: Text(
                    authState.offline
                        ? '${authState.user?.email ?? ''} · ${isEn ? 'offline' : 'sin conexión'}'
                        : authState.user?.email ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                  title: Text(
                    isEn ? 'Sign out' : 'Cerrar sesión',
                    style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Deletes the data stored on this phone. Settings are kept.'
                        : 'Borra los datos guardados en este celular. Se conservan los ajustes.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _confirmarCerrarSesion(isEn),
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
                title: const Text('Diagnóstico de sesión (debug)'),
                subtitle: Text(_diagnostico ?? '2 GET /auth/me en paralelo', style: const TextStyle(fontSize: 12)),
                onTap: _diagnosticarSesion,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Sección: Servidor (solo lectura; se fija al compilar)
          _buildSectionHeader(isEn ? 'Server' : 'Servidor'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: ListTile(
              leading: const Icon(Icons.dns_rounded),
              title: Text(isEn ? 'API address' : 'Dirección de la API'),
              subtitle: Text(
                ApiConfig.isConfigured
                    ? ApiConfig.baseUrl
                    : (isEn ? 'Not configured (API_BASE_URL)' : 'Sin configurar (API_BASE_URL)'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Sección: Módulos de Administración
          _buildSectionHeader('Módulos de Gestión Administrativa'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                _buildAdminTile(
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.emerald,
                  title: 'Cuentas y Medios de Pago',
                  subtitle: 'Gestionar bancos, billeteras y efectivo (ABM Lugares)',
                  onTap: () => context.push(AppRoutes.accountsAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.category_outlined,
                  color: AppColors.primary,
                  title: 'Rubros y Categorías',
                  subtitle: 'Crear, renombrar y activar categorías de gasto',
                  onTap: () => context.push(AppRoutes.categoriesAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.pie_chart_outline_rounded,
                  color: AppColors.amber,
                  title: 'Presupuestos y Topes de Gasto',
                  subtitle: 'Límites mensuales, alertas y renovación en 1 tap',
                  onTap: () => context.push(AppRoutes.limitsAdmin),
                ),
                const Divider(height: 1),
                _buildAdminTile(
                  icon: Icons.analytics_outlined,
                  color: AppColors.rose,
                  title: 'Reportes y Monitor de Precios',
                  subtitle: 'Analíticas visuales, gráficos y evolución de inflación',
                  onTap: () => context.push(AppRoutes.analytics),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Sección: Apariencia Visual
          _buildSectionHeader('Apariencia y Tema'),
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
                  const Text('Modo de Visualización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('Sistema'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Claro'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Oscuro'),
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
