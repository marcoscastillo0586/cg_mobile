import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import 'package:gastos_mobile/routes/app_routes.dart';
import '../../../../services/app_update_service.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlController.text = settings.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _probarConexion() async {
    AppFeedback.selection();
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      AppFeedback.showError(context, 'Ingresa una URL de servidor válida');
      return;
    }
    await ref.read(settingsProvider.notifier).probarConexion(url);
  }

  void _guardarUrl() async {
    AppFeedback.selection();
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      AppFeedback.showError(context, 'Ingresa una URL de servidor válida');
      return;
    }
    await ref.read(settingsProvider.notifier).cambiarBaseUrl(url);
    if (mounted) {
      AppFeedback.showSuccess(context, 'URL base del servidor actualizada correctamente');
    }
  }

  void _seleccionarPreset(String url) {
    AppFeedback.selection();
    _urlController.text = url;
    _guardarUrl();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes y Configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        children: [
          // 1. Sección: Auto-Actualizaciones OTA
          _buildSectionHeader('Actualizaciones del Sistema'),
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
                  const Text('Sistema de Actualización Local OTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    'Verifica si existe un paquete APK compilado más reciente en el servidor local de la PC.',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      AppFeedback.selection();
                      AppUpdateService.checkForUpdates(context, manual: true);
                    },
                    icon: const Icon(Icons.system_update_rounded, size: 18),
                    label: const Text('Buscar actualizaciones', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

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

          // 3. Sección: Servidor y Selector de Red / IP
          _buildSectionHeader('Conectividad y Servidor Backend'),
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
                  const Text(
                    'URL Base de la API',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Permite alternar entre tu PC en la red Wi-Fi, emulador o servidor remoto sin reinstalar la app.',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wifi_rounded, size: 16),
                        label: const Text('Wi-Fi LAN (192.168.0.50)'),
                        onPressed: () => _seleccionarPreset('http://192.168.0.50/gastos2.0'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.phone_android_rounded, size: 16),
                        label: const Text('Emulador (10.0.2.2)'),
                        onPressed: () => _seleccionarPreset('http://10.0.2.2/gastos2.0'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer_rounded, size: 16),
                        label: const Text('Localhost'),
                        onPressed: () => _seleccionarPreset('http://localhost/gastos2.0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Dirección URL del Backend',
                      prefixIcon: const Icon(Icons.dns_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (settingsState.connectionStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (settingsState.connectionOk == true ? AppColors.emerald : AppColors.rose)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (settingsState.connectionOk == true ? AppColors.emerald : AppColors.rose)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            settingsState.connectionOk == true
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: settingsState.connectionOk == true ? AppColors.emerald : AppColors.rose,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              settingsState.connectionStatus!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: settingsState.connectionOk == true
                                    ? AppColors.emerald
                                    : AppColors.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: settingsState.isTestingConnection ? null : _probarConexion,
                          icon: settingsState.isTestingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_ping_rounded, size: 18),
                          label: const Text('Probar Conexión'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: _guardarUrl,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Guardar IP'),
                        ),
                      ),
                    ],
                  ),
                ],
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
