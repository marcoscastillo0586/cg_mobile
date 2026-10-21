import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = settingsState.language == 'en';

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
