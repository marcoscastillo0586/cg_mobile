import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/settings_provider.dart';
import '../../../../l10n/l10n.dart';

class OnboardingDialog extends StatefulWidget {
  final String initialMoneda;
  final String initialIdioma;
  final void Function({required String moneda, required String idioma, required String nombreDashboard}) onConfirmar;

  const OnboardingDialog({
    super.key,
    required this.initialMoneda,
    required this.initialIdioma,
    required this.onConfirmar,
  });

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  late String _selectedMoneda;
  late String _selectedIdioma;

  /// Nombre del dashboard principal ("principal" por defecto).
  TextEditingController? _nombreDashboard;

  @override
  void initState() {
    super.initState();
    _selectedMoneda = widget.initialMoneda;
    _selectedIdioma = widget.initialIdioma;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nombreDashboard ??= TextEditingController(text: context.l10n.dashboardDefaultName);
  }

  @override
  void dispose() {
    _nombreDashboard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Text(context.l10n.initialSetup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.welcomePleaseChooseInitialPreferences,
              style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 16),

            // 1. Moneda Habitual
            Text(
              context.l10n.n1UsualCurrencyDefault,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedMoneda,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: SettingsNotifier.monedasDisponibles.map((code) {
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text(SettingsNotifier.currencyLabel(code, context.l10n)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMoneda = val);
              },
            ),
            const SizedBox(height: 16),

            // 2. Idioma de Preferencia
            Text(
              context.l10n.n2PreferredLanguage,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedIdioma,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: SettingsNotifier.idiomasDisponibles.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedIdioma = val);
              },
            ),
            const SizedBox(height: 16),

            // 3. Nombre del dashboard
            Text(
              '3. ${context.l10n.dashboardName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('onboarding-nombre-dashboard'),
              controller: _nombreDashboard,
              maxLength: 100,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final nombre = _nombreDashboard?.text.trim() ?? '';
            widget.onConfirmar(
              moneda: _selectedMoneda,
              idioma: _selectedIdioma,
              nombreDashboard: nombre.isEmpty ? context.l10n.dashboardDefaultName : nombre,
            );
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.start, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
